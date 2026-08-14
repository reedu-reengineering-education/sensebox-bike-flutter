//
//  SceneDelegate.swift
//  Runner
//
//  Created by Felix Erdmann on 14.08.26.
//


import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  @available(iOS 26.0, *)
  override func preferredWindowingControlStyle(
    for scene: UIWindowScene
  ) -> UIWindowScene.WindowingControlStyle {
    .minimal
  }
}