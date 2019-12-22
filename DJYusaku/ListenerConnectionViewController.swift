//
//  ListenerConnectionViewController.swift
//  DJYusaku
//
//  Created by Masahiro Nakamura on 2019/11/06.
//  Copyright © 2019 Yusaku. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class ListenerConnectionViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()

        ConnectionController.shared.startBrowse()
        ConnectionController.shared.delegate = self
        
        // tableViewのdelegate, dataSource設定
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        ConnectionController.shared.stopBrowse()
        ConnectionController.shared.connectableDJs.removeAll()
    }

}

// MARK: - UITableViewDataSource

extension ListenerConnectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ConnectionController.shared.connectableDJs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ListenerConnectableDJsTableViewCell", for: indexPath) as! ListenerConnectableDJsTableViewCell
        let peerID = ConnectionController.shared.connectableDJs[indexPath.row]
        let (displayName, imageUrlString) = ConnectionController.shared.connectableDJNameCorrespondence[peerID]!
        cell.djName?.text = displayName
        if imageUrlString != nil {
            if let imageUrl = URL(string: imageUrlString!) {
                cell.djImageView.image = Artwork.fetch(url: imageUrl)
            }
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension ListenerConnectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selected = ConnectionController.shared.connectableDJs[indexPath.row]
        ConnectionController.shared.startListener(selectedDJ: selected)
        
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - ConnectionControllerDelegate

extension ListenerConnectionViewController: ConnectionControllerDelegate {
    func connectionController(didChangeConnectableDevices devices: [MCPeerID]) {
        // browserがピアを見つけたらリロード
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
}
