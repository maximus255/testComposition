//
//  VideoViewController.swift
//  TestSegmentation
//
//  Created by admin on 22.04.2023.
//

import UIKit
import AVFoundation
import AVKit
class VideoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    @IBAction func exportButtonPressed(_ sender: UIButton) {
        do {
            let (composition, videoComposition, audioMix) = try makeComposition()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("tmp.MOV")
            
            FileManager.removeFileIfExists(url)
            
            export(asset: composition, outputUrl: url, videoComposition: videoComposition, audioMix: audioMix)
        } catch {
            print( "Failed to make composition. Description: \(error as NSError)")
        }
    }
    @IBAction func playButtonPressed(_ sender: Any) {
        do {
            let (composition, videoComposition, audioMix) = try makeComposition()
            
            let playItem = AVPlayerItem(asset: composition)
            playItem.videoComposition = videoComposition
            playItem.audioMix = audioMix
            
            let player = AVPlayer(playerItem: playItem)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            self.present(playerViewController, animated: true, completion: nil)
        } catch {
            print( "Failed to make composition. Description: \(error as NSError)")
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
