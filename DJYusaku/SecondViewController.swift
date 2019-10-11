//
//  SecondViewController.swift
//  DJYusaku
//
//  Created by Hayato Kohara on 2019/10/05.
//  Copyright © 2019 Yusaku. All rights reserved.
//

import UIKit
import MediaPlayer

class SecondViewController: UIViewController, MPMediaPickerControllerDelegate {
    
    let fromAppDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
//    var secondViewPlayer :MPMusicPlayerController!
//    var secondViewPlayer = self.fromAppDelegate.player
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let picker = MPMediaPickerController()
        picker.delegate = self
        picker.allowsPickingMultipleItems = true
        present(picker, animated: true, completion: nil)
        
//        secondViewPlayer = self.fromAppDelegate.player
//        secondViewPlayer = GlobalVar.shared.player
    }
    
    func mediaPicker(_ mediaPicker: MPMediaPickerController, didPickMediaItems mediaItemCollection: MPMediaItemCollection) {
        AppDelegate.player.setQueue(with: mediaItemCollection)
        AppDelegate.player.play()
        dismiss(animated: true, completion: nil)
    }
    func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
        
        dismiss(animated: true, completion: nil)
    }


}

