import Foundation
import CoreData
import UIKit

public class Song: AbstractPlayable, Identifyable {

    let managedObject: SongMO

    init(managedObject: SongMO) {
        self.managedObject = managedObject
        super.init(managedObject: managedObject)
    }

    var album: Album? {
        get {
            guard let albumMO = managedObject.album else { return nil }
            return Album(managedObject: albumMO)
        }
        set {
            if managedObject.album != newValue?.managedObject { managedObject.album = newValue?.managedObject }
        }
    }
    var artist: Artist? {
        get {
            guard let artistMO = managedObject.artist else { return nil }
            return Artist(managedObject: artistMO)
        }
        set {
            if managedObject.artist != newValue?.managedObject { managedObject.artist = newValue?.managedObject }
        }
    }
    var genre: Genre? {
        get {
            guard let genreMO = managedObject.genre else { return nil }
            return Genre(managedObject: genreMO) }
        set {
            if managedObject.genre != newValue?.managedObject { managedObject.genre = newValue?.managedObject }
        }
    }
    var syncInfo: SyncWave? {
        get {
            guard let syncInfoMO = managedObject.syncInfo else { return nil }
            return SyncWave(managedObject: syncInfoMO) }
        set {
            if managedObject.syncInfo != newValue?.managedObject { managedObject.syncInfo = newValue?.managedObject }
        }
    }
    var isOrphaned: Bool {
        guard let album = album else { return true }
        return album.isOrphaned
    }

    override var creatorName: String {
        return artist?.name ?? "Unknown Artist"
    }
    
    var detailInfo: String {
        var info = displayString
        info += " ("
        let albumName = album?.name ?? "-"
        info += "album: \(albumName),"
        let genreName = genre?.name ?? "-"
        info += " genre: \(genreName),"
        
        info += " id: \(id),"
        info += " track: \(track),"
        info += " year: \(year),"
        info += " duration: \(duration),"
        let diskInfo =  disk ?? "-"
        info += " disk: \(diskInfo),"
        info += " size: \(size),"
        let contentTypeInfo = contentType ?? "-"
        info += " contentType: \(contentTypeInfo),"
        info += " bitrate: \(bitrate)"
        info += ")"
        return info
    }
    
    var identifier: String {
        return title
    }

    override var image: UIImage {
        if let curAlbum = album, !curAlbum.isOrphaned, curAlbum.image != Artwork.defaultImage {
            return curAlbum.image
        }
        if super.image != Artwork.defaultImage {
            return super.image
        }
        if let artistArt = artist?.artwork?.image {
            return artistArt
        }
        return Artwork.defaultImage
    }

}

extension Array where Element: Song {
    
    func filterCached() -> [Element] {
        return self.filter{ $0.isCached }
    }
    
    func filterCustomArt() -> [Element] {
        return self.filter{ $0.artwork != nil }
    }
    
    var hasCachedSongs: Bool {
        return self.lazy.filter{ $0.isCached }.first != nil
    }
    
    func sortByTrackNumber() -> [Element] {
        return self.sorted{ $0.track < $1.track }
    }

}
