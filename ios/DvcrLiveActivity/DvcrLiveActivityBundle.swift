//
//  DvcrLiveActivityBundle.swift
//  DvcrLiveActivity
//

import SwiftUI
import WidgetKit

@main
struct DvcrLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    if #available(iOS 16.1, *) {
      DvcrLiveActivityLiveActivity()
    }
  }
}
