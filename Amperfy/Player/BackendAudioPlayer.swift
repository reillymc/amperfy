import Foundation
import AVFoundation
import os.log

enum FetchErrorReaction {
    case playPrevious
    case playPreviousCached
    case playNext
    case playNextCached
    case stop
}

protocol BackendAudioPlayerNotifiable {
    func didElapsedTimeChange()
    func stop()
    func playPrevious()
    func playPreviousCached()
    func playNext()
    func playNextCached()
    func didItemFinishedPlaying()
    func notifyItemPreparationFinished()
}

struct PlayRequest {
    let playlistItem: PlaylistItem
    let reactionToError: FetchErrorReaction
}

class BackendAudioPlayer {

    private let playableDownloader: DownloadManageable
    private let cacheProxy: PlayableFileCachable
    private let backendApi: BackendApi
    private let userStatistics: UserStatistics
    private let player: AVPlayer
    private let eventLogger: EventLogger
    private let updateElapsedTimeInterval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    private var latestPlayRequest: PlayRequest?
    private let semaphore = DispatchSemaphore(value: 1)
    
    public var isAutoCachePlayedItems: Bool = true
    public private(set) var isPlaying: Bool = false
    public private(set) var currentlyPlaying: PlaylistItem?
    
    var responder: BackendAudioPlayerNotifiable?
    var elapsedTime: Double {
        guard player.currentItem?.status == AVPlayerItem.Status.readyToPlay else {
            return 0.0
        }
        let elapsedTimeInSeconds = player.currentTime().seconds
        guard elapsedTimeInSeconds.isFinite else {
            return 0.0
        }
        return elapsedTimeInSeconds
    }
    var duration: Double {
        guard player.currentItem?.status == AVPlayerItem.Status.readyToPlay,
              let duration = player.currentItem?.asset.duration.seconds,
              duration.isFinite else {
            return 0.0
        }
        return duration
    }
    var canBeContinued: Bool {
        return player.currentItem != nil
    }
    
    init(mediaPlayer: AVPlayer, eventLogger: EventLogger, backendApi: BackendApi, playableDownloader: DownloadManageable, cacheProxy: PlayableFileCachable, userStatistics: UserStatistics) {
        self.player = mediaPlayer
        self.backendApi = backendApi
        self.eventLogger = eventLogger
        self.playableDownloader = playableDownloader
        self.cacheProxy = cacheProxy
        self.userStatistics = userStatistics
        
        player.addPeriodicTimeObserver(forInterval: updateElapsedTimeInterval, queue: DispatchQueue.main) { [weak self] time in
            if let self = self {
                self.responder?.didElapsedTimeChange()
            }
        }
    }
    
    @objc private func itemFinishedPlaying() {
        responder?.didItemFinishedPlaying()
    }
    
    func continuePlay() {
        isPlaying = true
        player.play()
    }
    
    func pause() {
        isPlaying = false
        player.pause()
    }
    
    func stop() {
        isPlaying = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentlyPlaying = nil
    }
    
    func seek(toSecond: Double) {
        player.seek(to: CMTime(seconds: toSecond, preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
    }
    
    func updateCurrentlyPlayingReference(playlistItem: PlaylistItem) {
        if currentlyPlaying?.playable?.id == playlistItem.playable?.id {
            currentlyPlaying = playlistItem
        }
    }
    
    func requestToPlay(playlistItem: PlaylistItem, reactionToError: FetchErrorReaction) {
        semaphore.wait()
        latestPlayRequest = PlayRequest(playlistItem: playlistItem, reactionToError: reactionToError)
        guard let playable = playlistItem.playable else { return }
        if !playable.isPlayableOniOS, let contentType = playable.contentType {
            player.pause()
            player.replaceCurrentItem(with: nil)
            eventLogger.info(topic: "Player Info", statusCode: .playerError, message: "Content type \"\(contentType)\" of \"\(playable.displayString)\" is not playable via Amperfy.")
        } else {
            if playable.isCached {
                insertCachedPlayable(playlistItem: playlistItem)
            } else {
                insertStreamPlayable(playlistItem: playlistItem)
                if isAutoCachePlayedItems {
                    playableDownloader.download(object: playable, notifier: nil, priority: .high)
                }
            }
        }
        self.continuePlay()
        self.reactToInsertationFinish(playlistItem: playlistItem)
        semaphore.signal()
    }
    
    private func insertCachedPlayable(playlistItem: PlaylistItem) {
        guard let playable = playlistItem.playable, let playableData = cacheProxy.getFile(forPlayable: playable)?.data else { return }
        os_log(.default, "Play item: %s", playable.displayString)
        if playable.isSong { userStatistics.playedSong(isPlayedFromCache: true) }
        let url = createLocalUrl(forFileData: playableData)
        insert(playable: playable, withUrl: url)
    }
    
    private func insertStreamPlayable(playlistItem: PlaylistItem) {
        guard let playable = playlistItem.playable, let streamUrl = backendApi.generateUrl(forStreamingPlayable: playable) else { return }
        os_log(.default, "Stream item: %s", playable.displayString)
        if playable.isSong { userStatistics.playedSong(isPlayedFromCache: false) }
        insert(playable: playable, withUrl: streamUrl)
    }

    private func insert(playable: AbstractPlayable, withUrl url: URL) {
        player.pause()
        player.replaceCurrentItem(with: nil)
        var item: AVPlayerItem?
        if let mimeType = playable.iOsCompatibleContentType {
            let asset: AVURLAsset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey" : mimeType])
            item = AVPlayerItem(asset: asset)
        } else {
            item = AVPlayerItem(url: url)
        }
        player.replaceCurrentItem(with: item)
        NotificationCenter.default.addObserver(self, selector: #selector(itemFinishedPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    }
    
    private func reactToInsertationFinish(playlistItem: PlaylistItem) {
        currentlyPlaying = playlistItem
        self.responder?.notifyItemPreparationFinished()
    }
    
    private func reactToError(reaction: FetchErrorReaction) {
        switch reaction {
        case .playPrevious:
            self.responder?.playPrevious()
        case .playPreviousCached:
            self.responder?.playPreviousCached()
        case .playNext:
            self.responder?.playNext()
        case .playNextCached:
            self.responder?.playNextCached()
        case .stop:
            self.responder?.stop()
        }
    }
    
    private func createLocalUrl(forFileData fileData: Data) -> URL {
        let tempDirectoryURL = NSURL.fileURL(withPath: NSTemporaryDirectory(), isDirectory: true)
        let url = tempDirectoryURL.appendingPathComponent("curPlayItem.mp3")
        try! fileData.write(to: url, options: Data.WritingOptions.atomic)
        return url
    }
    
}
