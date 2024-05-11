//
//  ViewController.swift
//  test1
//
//  Created by Robert Diamond on 4/19/24.
//

import UIKit

class ViewController: UITableViewController, UITableViewDataSourcePrefetching {
    var queue = DispatchQueue(label:"preloads", qos: .background)
    var lock = NSLock()
    
    let indexUrl = URL(string: "https://hacker-news.firebaseio.com/v0/newstories.json")
    var index = [UInt]()
    var cachedContent = [Int: [String:Any]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Hacker News"
        self.tableView.prefetchDataSource = self
        self.tableView.refreshControl = UIRefreshControl()
        self.tableView.refreshControl?.addTarget(self, action: #selector(loadIndex), for: .valueChanged)
        // Do any additional setup after loading the view.
        loadIndex()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return index.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "basicCell")
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "basicCell")
        }
        var content = cell?.defaultContentConfiguration()
        cell?.accessoryType = .detailDisclosureButton
        lock.lock()
        if let record = cachedContent[indexPath.row] {
            content?.text = record["title"] as? String ?? "(unknown)"
            var byline = ""
            if let author = record["by"] {
                byline = "by \(author)"
            }
            if let pubdate = record["time"] as? Double {
                let date = Date(timeIntervalSince1970: pubdate)
                byline.append(" on \(date.formatted())")
            }
            content?.secondaryText = byline
        } else {
            let row = indexPath.row
            content?.text = String(index[row])
        }
        lock.unlock()
        cell?.contentConfiguration = content
        return cell!
    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        queue.async { [self] in
            for idx in indexPaths {
                loadRow(row: idx.row)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        lock.lock()
        if cachedContent[indexPath.row] != nil {
            lock.unlock()
            return
        }
        lock.unlock()
        self.loadRow(row: indexPath.row)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "openstory", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let indexPath = self.tableView.indexPathForSelectedRow else { return }
        guard let record = self.cachedContent[indexPath.row] else { return }
        (segue.destination as? DetailViewController)?.record = record
    }
    
    func loadRow(row : Int) {
        let session = URLSession.shared
        if row >= index.count { return }
        lock.lock()
        if cachedContent[row] != nil {
            lock.unlock()
            return
        }
        lock.unlock()
        let id = index[row]
        guard let url = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json")
        else { return }
        lock.lock()
        cachedContent[row] = [
            "loading": true
        ]
        lock.unlock()
        let request = URLRequest(url: url)
        
        session.dataTask(with: request) { [self] data, response, error in
            if let error = error {
                self.handleError(error: error.localizedDescription)
                return
            }
            if let data = data {
                if let content = try? JSONSerialization.jsonObject(with: data) {
                    lock.lock()
                    self.cachedContent[row] = content as? [String : Any]
                    lock.unlock()
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }
            }
        }.resume()
    }
    
    @objc
    func loadIndex() {
        guard let indexUrl = indexUrl else {
            handleError(error: "URL is empty or error")
            return
        }
        queue.async { [self] in
            let session = URLSession.shared
            let request = URLRequest(url: indexUrl)
            session.dataTask(with: request) { data, response, error in
                if let error = error {
                    self.handleError(error: error.localizedDescription)
                    return
                }
                if let data = data {
                    if let content = try? JSONSerialization.jsonObject(with: data) {
                        if let content = content as? [UInt] {
                            content.reversed().forEach { item in
                                if !self.index.contains(item) {
                                    self.index.insert(item, at: 0)
                                }
                            }
                        }
                        DispatchQueue.main.async {
                            self.refreshControl?.endRefreshing()
                            self.tableView.reloadData()
                        }
                    }
                }
            }.resume()
        }
    }
    
    func handleError(error: String) {
        
    }

}

