//
//  ConnectionController.swift
//  DJYusaku
//
//  Created by Masahiro Nakamura on 2019/11/06.
//  Copyright © 2019 Yusaku. All rights reserved.
//

import Foundation
import MultipeerConnectivity

extension Notification.Name {
    static let DJYusakuConnectionControllerNowPlayingSongDidChange = Notification.Name("DJYusakuConnectionControllerNowPlayingSongDidChange")
}

class ConnectionController: NSObject {
    static let shared = ConnectionController()
    
    public weak var delegate: ConnectionControllerDelegate?
    
    let serviceType = "djyusaku"
    
    var peerID = MCPeerID(displayName: UIDevice.current.name)
    var session: MCSession!
    var advertiser: MCNearbyServiceAdvertiser!
    var browser: MCNearbyServiceBrowser!
    
    var connectableDJs: [MCPeerID] = []
    var connectedDJ: MCPeerID!
    
    var isParent: Bool!
    
    var receivedSongs: [Song] = []
    
    func initialize(isParent: Bool, displayName: String) {
        self.isParent = isParent
        self.connectableDJs.removeAll()

        self.session = MCSession(peer: self.peerID)
        session.delegate = self

        if advertiser != nil {
            self.stopAdvertise()
        }
        advertiser = MCNearbyServiceAdvertiser(peer: self.peerID, discoveryInfo: nil, serviceType: self.serviceType)
        advertiser.delegate = self

        if browser != nil {
            self.stopBrowse()
        }
        browser = MCNearbyServiceBrowser(peer: self.peerID, serviceType: self.serviceType)
        browser.delegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(viewWillEnterForeground), name: .DJYusakuRequestVCWillEnterForeground, object: nil)
    }
    
    @objc func viewWillEnterForeground() {
        guard connectedDJ != nil else { return }
        ConnectionController.shared.browser.invitePeer(connectedDJ, to: ConnectionController.shared.session, withContext: nil, timeout: 10.0)
    }
    
    func startAdvertise() {
        advertiser.startAdvertisingPeer()
    }
    
    func stopAdvertise() {
        advertiser.stopAdvertisingPeer()
    }

    func startBrowse() {
        browser.startBrowsingForPeers()
    }
    
    func stopBrowse() {
        browser.stopBrowsingForPeers()
    }
    
}

// MARK: - MCSessionDelegate

extension ConnectionController: MCSessionDelegate {
    // 接続ピアの状態が変化したとき呼ばれる
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == .connected {
            print("Peer \(peerID.displayName) is connected.")
            if ConnectionController.shared.isParent {   // DJが新しい子機と接続したとき
                var songs: [Song] = []
                for i in 0..<PlayerQueue.shared.count() {
                    songs.append(PlayerQueue.shared.get(at: i)!)
                }
                let songsData = try! JSONEncoder().encode(songs)
                let messageData = try! JSONEncoder().encode(MessageData(desc:  MessageData.Name.requestSongs, value: songsData))
                do {
                    try ConnectionController.shared.session.send(messageData, toPeers: [peerID], with: .unreliable)
                } catch let error {
                    print(error)
                }
            }
        } else {
            print("Peer \(peerID.displayName) is not connected.")
        }
    }
    
    // 他のピアによる send を受け取ったとき呼ばれる
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("\(peerID)から \(String(data: data, encoding: .utf8)!)を受け取りました")
        
        if ConnectionController.shared.isParent {   // DJがデータを受け取ったとき
            let song = try! JSONDecoder().decode(Song.self, from: data)
            PlayerQueue.shared.add(with: song)
        } else {                                    // リスナーがデータを受け取ったとき
            let messageData = try! JSONDecoder().decode(MessageData.self, from: data)
            switch messageData.desc {
                case MessageData.Name.requestSongs:
                    let songs = try! JSONDecoder().decode([Song].self, from: messageData.value)
                    receivedSongs = songs
                    NotificationCenter.default.post(name: .DJYusakuPlayerQueueDidUpdate, object: nil)
                case MessageData.Name.nowPlaying:
                    let nowPlaying = try! JSONDecoder().decode(Song.self, from: messageData.value)
                    NotificationCenter.default.post(name: .DJYusakuConnectionControllerNowPlayingSongDidChange, object: nil, userInfo: ["song": nowPlaying as Any])
            }
        }
        
        self.delegate?.connectionController(didReceiveData: data, from: peerID)
    }
    
    // 他のピアによる sendStream を受け取ったとき呼ばれる
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        print(#function)
        // Do nothing
    }
    
    // 他のピアによる sendResource を受け取ったとき呼ばれる
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        print(#function)
        // Do nothing
    }
    
    // 他のピアによる sendResource を受け取ったとき呼ばれる
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        print(#function)
        // Do nothing
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension ConnectionController: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension ConnectionController: MCNearbyServiceBrowserDelegate {

    // 接続可能なピアが見つかったとき
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        self.connectableDJs.append(peerID)
            
        self.delegate?.connectionController(didChangeConnectableDevices: self.connectableDJs)
    }

    // 接続可能なピアが消えたとき
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        self.connectableDJs = connectableDJs.filter { $0 != peerID }
        
        self.delegate?.connectionController(didChangeConnectableDevices: self.connectableDJs)
    }
    /// エラーが起こったとき
    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
    }

}
