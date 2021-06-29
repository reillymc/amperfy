import UIKit

class LibraryElementDetailTableHeaderView: UIView {
    
    @IBOutlet weak var playAllButton: UIButton!
    @IBOutlet weak var addAllToPlaylistButton: UIButton!
    
    static let frameHeight: CGFloat = 30.0 + margin.top + margin.bottom
    static let margin = UIView.defaultMarginMiddleElement
    
    private var playableContainer: PlayableContainable?
    private var player: MusicPlayer?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.layoutMargins = Self.margin
    }
    
    @IBAction func playAllButtonPressed(_ sender: Any) {
        guard let playableContainer = playableContainer, let player = player else { return }
        player.cleanPlaylist()
        player.addToPlaylist(playables: playableContainer.playables)
        player.play()
    }
    
    @IBAction func addAllToPlayNextButtonPressed(_ sender: Any) {
        guard let playableContainer = playableContainer, let player = player else { return }
        player.addToPlaylist(playables: playableContainer.playables)
    }
    
    func prepare(playableContainer: PlayableContainable?, with player: MusicPlayer) {
        self.playableContainer = playableContainer
        self.player = player
    }
    
}
