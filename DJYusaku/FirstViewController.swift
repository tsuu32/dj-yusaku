//
//  FirstViewController.swift
//  DJYusaku
//
//  Created by Hayato Kohara on 2019/10/05.
//  Copyright © 2019 Yusaku. All rights reserved.
//

import UIKit
import MediaPlayer

class FirstViewController: UIViewController {
    
    let fromAppDelegate: AppDelegate = UIApplication.shared.delegate as! AppDelegate
//    var firstViewPlayer :MPMusicPlayerController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
//        firstViewPlayer = self.fromAppDelegate.player
//        firstViewPlayer = GlobalVar.shared
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func playButton(_ sender: Any) {
//        print("play")
        AppDelegate.player.play()
    }
    
    @IBAction func pauseButton(_ sender: Any) {
//        print("pause")
        AppDelegate.player.pause()
    }
    
    @IBAction func stopButton(_ sender: Any) {
//        print("stop")
        print(AppDelegate.player)
        AppDelegate.player.stop()
    }
}
