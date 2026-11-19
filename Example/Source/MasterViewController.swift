//
//  MasterViewController.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Alamofire
import UIKit

class MasterViewController: UITableViewController {
    // MARK: - Properties

    @IBOutlet var titleImageView: UIImageView!

    var detailViewController: DetailViewController?

    private var reachability: NetworkReachabilityManager!

    // MARK: - View Lifecycle

    override func awakeFromNib() {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering awakeFromNib()\n".utf8))
        super.awakeFromNib()

        navigationItem.titleView = titleImageView
		FileHandle.standardError.write(Data("[DEBUG] awakeFromNib(): navigationItem.titleView → \(navigationItem.titleView)\n".utf8))
        clearsSelectionOnViewWillAppear = true
		FileHandle.standardError.write(Data("[DEBUG] awakeFromNib(): clearsSelectionOnViewWillAppear → \(clearsSelectionOnViewWillAppear)\n".utf8))

        reachability = NetworkReachabilityManager.default
		FileHandle.standardError.write(Data("[DEBUG] awakeFromNib(): reachability → \(reachability)\n".utf8))
        monitorReachability()
		FileHandle.standardError.write(Data("[WARN] <<< Exiting awakeFromNib()\n".utf8))
    }

    // MARK: - UIStoryboardSegue

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering prepare(segue=\(segue),sender=\(sender))\n".utf8))
        let __logStart = ContinuousClock.now
        if
            let navigationController = segue.destination as? UINavigationController,
            let detailViewController = navigationController.topViewController as? DetailViewController {
            func requestForSegue(_ segue: UIStoryboardSegue) -> Request? {
                switch segue.identifier! {
                case "GET":
                    detailViewController.segueIdentifier = "GET"
                    return AF.request("https://httpbin.org/get")
                case "POST":
                    detailViewController.segueIdentifier = "POST"
                    return AF.request("https://httpbin.org/post", method: .post)
                case "PUT":
                    detailViewController.segueIdentifier = "PUT"
                    return AF.request("https://httpbin.org/put", method: .put)
                case "DELETE":
                    detailViewController.segueIdentifier = "DELETE"
                    return AF.request("https://httpbin.org/delete", method: .delete)
                case "DOWNLOAD":
                    detailViewController.segueIdentifier = "DOWNLOAD"
                    let destination = DownloadRequest.suggestedDownloadDestination(for: .cachesDirectory,
                                                                                   in: .userDomainMask)
                    return AF.download("https://httpbin.org/stream/1", to: destination)
                default:
                    return nil
                }
            }

            if let request = requestForSegue(segue) {
                detailViewController.request = request
				FileHandle.standardError.write(Data("[DEBUG] prepare(segue=\(segue),sender=\(sender)): detailViewController.segueIdentifier → \(detailViewController.segueIdentifier)\n".utf8))
            }
        }
		FileHandle.standardError.write(Data("[DEBUG] prepare(segue=\(segue),sender=\(sender)): detailViewController.request → \(detailViewController.request)\n".utf8))
    FileHandle.standardError.write(Data("[ERROR] prepare(segue,sender)=\(segue),\(sender): external service call took \(Int((ContinuousClock.now - __logStart) / .milliseconds(1))) ms\n".utf8))
    FileHandle.standardError.write(Data("[WARN] <<< Exiting prepare(segue=\(segue),sender=\(sender))\n".utf8))
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering tableView(tableView=\(tableView),indexPath=\(indexPath))\n".utf8))
        if indexPath.section == 3 && indexPath.row == 0 {
            print("Reachability Status: \(reachability.status)")
            tableView.deselectRow(at: indexPath, animated: true)
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting tableView(tableView=\(tableView),indexPath=\(indexPath))\n".utf8))
    }

    // MARK: - Private - Reachability

    private func monitorReachability() {
		FileHandle.standardError.write(Data("[ERROR] >>> Entering monitorReachability()\n".utf8))
        reachability.startListening { status in
            print("Reachability Status Changed: \(status)")
        }
		FileHandle.standardError.write(Data("[WARN] <<< Exiting monitorReachability()\n".utf8))
    }
}
