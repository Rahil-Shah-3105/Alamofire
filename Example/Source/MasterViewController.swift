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
		print(">>> Entering awakeFromNib()")
        super.awakeFromNib()

        navigationItem.titleView = titleImageView
		print("awakeFromNib(): navigationItem.titleView → \(navigationItem.titleView)")
		print("awakeFromNib(): clearsSelectionOnViewWillAppear → \(clearsSelectionOnViewWillAppear)")
        clearsSelectionOnViewWillAppear = true

        reachability = NetworkReachabilityManager.default
		print("awakeFromNib(): reachability → \(reachability)")
        monitorReachability()
		print("<<< Exiting awakeFromNib()")
    }

    // MARK: - UIStoryboardSegue

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		print(">>> Entering prepare(segue=\(segue),sender=\(sender))")
        if
            let navigationController = segue.destination as? UINavigationController,
            let detailViewController = navigationController.topViewController as? DetailViewController {
            func requestForSegue(_ segue: UIStoryboardSegue) -> Request? {
				let __logStart = ContinuousClock.now
				print(">>> Entering requestForSegue(segue=\(segue))")
                switch segue.identifier! {
                case "GET":
                    detailViewController.segueIdentifier = "GET"
					print("requestForSegue(segue=\(segue)): detailViewController.segueIdentifier → \(detailViewController.segueIdentifier)")
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
					print("requestForSegue(segue)=\(segue): external service call took \(Int((ContinuousClock.now - __logStart) / .milliseconds(1))) ms")
					print("<<< Exiting requestForSegue(segue=\(segue))")
                    return nil
                }
            }

            if let request = requestForSegue(segue) {
                detailViewController.request = request
            }
        }
		print(">>> Entering monitorReachability()")
		print("<<< Exiting monitorReachability()")
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		print(">>> Entering tableView(tableView=\(tableView),indexPath=\(indexPath))")
        if indexPath.section == 3 && indexPath.row == 0 {
            print("Reachability Status: \(reachability.status)")
            tableView.deselectRow(at: indexPath, animated: true)
        }
		print("<<< Exiting tableView(tableView=\(tableView),indexPath=\(indexPath))")
    }

    // MARK: - Private - Reachability

    private func monitorReachability() {
        reachability.startListening { status in
            print("Reachability Status Changed: \(status)")
        }
    }
}
