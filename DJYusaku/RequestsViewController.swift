//
//  RequestsViewController.swift
//  DJYusaku
//
//  Created by Hayato Kohara on 2019/10/05.
//  Copyright © 2019 Yusaku. All rights reserved.
//

import UIKit
import StoreKit
import MediaPlayer

extension Notification.Name {
    static let DJYusakuRequestVCWillEnterForeground = Notification.Name("DJYusakuRequestVCWillEnterForeground")
}
class RequestsViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var playingArtwork: UIImageView!
    @IBOutlet weak var playingTitle: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    private var isCapableAppleMusic: Bool = false
    private var isViewAppearedAtLeastOnce: Bool = false
    
    private let cloudServiceController = SKCloudServiceController()
    private let defaultArtwork: UIImage = UIImage()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // tableViewのdelegate, dataSource設定
        tableView.delegate = self
        tableView.dataSource = self
        
        let footerView = UIView()
        footerView.frame.size.height = tableView.rowHeight
        tableView.tableFooterView = footerView // 空のセルの罫線を消す
        
        playingArtwork.layer.cornerRadius = playingArtwork.frame.size.width * 0.05
        playingArtwork.clipsToBounds = true
        
        // Apple Musicライブラリへのアクセス許可の確認
        SKCloudServiceController.requestAuthorization { status in
            guard status == .authorized else { return }
            // Apple Musicの曲が再生可能か確認
            self.cloudServiceController.requestCapabilities { (capabilities, error) in
                if error == nil && capabilities.contains(.musicCatalogPlayback) {
                    self.isCapableAppleMusic = true
                }
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleRequestsDidUpdate), name: .DJYusakuPlayerQueueDidUpdate, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleNowPlayingItemDidChange), name: .DJYusakuPlayerQueueNowPlayingSongDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlaybackStateDidChange), name: .DJYusakuPlayerQueuePlaybackStateDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(changeListenerNowPlaying), name: .DJYusakuConnectionControllerNowPlayingSongDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(viewWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        navigationItem.rightBarButtonItem = editButtonItem
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.isViewAppearedAtLeastOnce {  // 初回だけ表示する画面遷移に使う
            // 初回にはWelcomeViewをモーダルを表示
            let storyboard: UIStoryboard = self.storyboard!
            let welcomNavigationController = storyboard.instantiateViewController(withIdentifier: "WelcomeNavigation") as! UINavigationController
            welcomNavigationController.isModalInPresentation = true
            let welcomeViewController = welcomNavigationController.viewControllers.first as! WelcomeViewController
            welcomeViewController.isCapableAppleMusic = self.isCapableAppleMusic
            self.present(welcomNavigationController, animated: true)
            
            // 2度目以降の表示はしない
            self.isViewAppearedAtLeastOnce = true
        }
    }
    
    @objc func handleRequestsDidUpdate(){
        DispatchQueue.main.async{
            self.tableView.reloadData()
        }
    }
    
    @objc func handleNowPlayingItemDidChange(){
        guard let nowPlayingItem = PlayerQueue.shared.mpAppController.nowPlayingItem else { return }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.playingTitle.text    = nowPlayingItem.title
            self.playingArtwork.image = nowPlayingItem.artwork?.image(at: CGSize(width: 48, height: 48))
        }
        
        guard ConnectionController.shared.session.connectedPeers.count != 0 else { return }
        
        let nowPlaying = Song(
            title      : nowPlayingItem.title ?? "Loding...",
            artist     : "",
            artworkUrl : PlayerQueue.shared.getArtworkURL(storeID: nowPlayingItem.playbackStoreID) ?? URL(fileURLWithPath: ""),
            id         : ""
        )
        let nowPlayingData = try! JSONEncoder().encode(nowPlaying)
        let messageData = try! JSONEncoder().encode(MessageData(desc: MessageData.Name.nowPlaying, value: nowPlayingData))
        do {
            try ConnectionController.shared.session.send(messageData, toPeers: ConnectionController.shared.session.connectedPeers, with: .unreliable)
        } catch let error {
            print(error)
        }
    }
    
    @objc func handlePlaybackStateDidChange(notification: NSNotification) {
        switch PlayerQueue.shared.mpAppController.playbackState {
        case .playing:
            playButton.setImage(UIImage(systemName: "pause.fill"), for: UIControl.State.normal)
        case .paused, .stopped:
            playButton.setImage(UIImage(systemName: "play.fill"), for: UIControl.State.normal)
        default:
            break
        }
    }
    
    @objc func changeListenerNowPlaying(notification: NSNotification){
        guard let song = notification.userInfo!["song"] as? Song else { return }
        let image = Artwork.fetch(url: song.artworkUrl)
        DispatchQueue.main.async {
            self.tableView.reloadData()
            self.playingTitle.text    = song.title
            self.playingArtwork.image = image
        }
    }
    
    @objc func viewWillEnterForeground() {
        guard ConnectionController.shared.isParent != nil else { return }
        if !ConnectionController.shared.isParent {
            NotificationCenter.default.post(
                name: .DJYusakuRequestVCWillEnterForeground,
                object: nil
            )
        }
    }
    
    @IBAction func playButton(_ sender: Any) {
        switch PlayerQueue.shared.mpAppController.playbackState {
        case .playing:          // 再生中なら停止する
            PlayerQueue.shared.mpAppController.pause()
        case .paused, .stopped: // 停止中なら再生する
            PlayerQueue.shared.mpAppController.play()
        default:
            break
        }
    }
    
    @IBAction func skipButton(_ sender: Any) {
        PlayerQueue.shared.mpAppController.skipToNextItem()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: true)
        tableView.isEditing = editing
    }
}

// MARK: - UITableViewDataSource

extension RequestsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard ConnectionController.shared.isParent != nil else { return 0 }
        if ConnectionController.shared.isParent {
            return PlayerQueue.shared.count()
        } else {
            return ConnectionController.shared.receivedSongs.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RequestsMusicTableViewCell", for: indexPath) as! RequestsMusicTableViewCell
        var song: Song
        if ConnectionController.shared.isParent {
            guard let queueSong = PlayerQueue.shared.get(at: indexPath.row) else { return cell }
            song = queueSong
        } else {
            song = ConnectionController.shared.receivedSongs[indexPath.row]
        }
        
        cell.title.text    = song.title
        cell.artist.text   = song.artist
        
        DispatchQueue.global().async {
            let image = Artwork.fetch(url: song.artworkUrl)
            DispatchQueue.main.async {
                cell.artwork.image = image  // 画像の取得に失敗していたらnilが入ることに注意
                cell.artwork.setNeedsLayout()
            }
        }
        
        return cell
    }
    
    // 全セルが削除可能
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard ConnectionController.shared.isParent != nil else { return false }
        return ConnectionController.shared.isParent
    }
    
    // 全セルが編集可能
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard ConnectionController.shared.isParent != nil else { return false }
        return ConnectionController.shared.isParent
    }
    
    // 編集時の動作
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if ConnectionController.shared.isParent { //自分がDJのとき
            PlayerQueue.shared.move(from: sourceIndexPath.row, to: destinationIndexPath.row)
        }
    }
}

// MARK: - UITableViewDelegate

extension RequestsViewController: UITableViewDelegate {
    // セルの編集時の挙動
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            PlayerQueue.shared.remove(at: indexPath.row) {
                tableView.deleteRows(at: [indexPath], with: .left)  // 必ずPlayerQueueの処理後にTableViewの更新を行う
            }
        }
    }
}
