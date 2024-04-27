//
//  DetailViewController.swift
//  test1
//
//  Created by Robert Diamond on 4/23/24.
//

import Foundation
import WebKit

class DetailViewController : UIViewController {
    @IBOutlet weak var webView: WKWebView!
    public var record: [String: Any]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let title = record?["title"] as? String ?? "Detail View"
        self.title = title
        guard let url = record?["url"] as? String else { return }
        let request = URLRequest(url: URL(string: url)!)
        webView.load(request)
    }
}
