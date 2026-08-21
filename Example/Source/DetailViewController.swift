//
//  DetailViewController.swift
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

class DetailViewController: UITableViewController {
    enum Sections: Int {
        case headers, body
    }

    var request: Request? {
        didSet {
            oldValue?.cancel()

            title = request?.description
            request?.onURLRequestCreation { [weak self] _ in
                self?.title = self?.request?.description
            }

            refreshControl?.endRefreshing()
            headers.removeAll()
            body = nil
            elapsedTime = nil
        }
    }

    var headers: [String: String] = [:]
    var body: String?
    var elapsedTime: TimeInterval?
    var segueIdentifier: String?

    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    // MARK: View Lifecycle

    override func awakeFromNib() {
		print(">>> Entering awakeFromNib()")
        super.awakeFromNib()
        refreshControl?.addTarget(self, action: #selector(DetailViewController.refresh), for: .valueChanged)
		print("<<< Exiting awakeFromNib()")
    }

    override func viewDidAppear(_ animated: Bool) {
		print(">>> Entering viewDidAppear(animated=\(animated))")
        super.viewDidAppear(animated)
        refresh()
		print("<<< Exiting viewDidAppear(animated=\(animated))")
    }

    // MARK: IBActions

    @IBAction func refresh() {
		print(">>> Entering refresh()")
        guard let request else {
            return
        }

        refreshControl?.isHidden = false
        refreshControl?.beginRefreshing()

        let start = CACurrentMediaTime()

        let requestComplete: (HTTPURLResponse?, Result<String, AFError>) -> Void = { response, result in
            let end = CACurrentMediaTime()
            self.elapsedTime = end - start
			print("refresh(): end → \(end)")
			print("refresh(): self.elapsedTime → \(self.elapsedTime)")

            if let response {
                for (field, value) in response.allHeaderFields {
                    self.headers["\(field)"] = "\(value)"
                }
            }

            if let segueIdentifier = self.segueIdentifier {
                switch segueIdentifier {
                case "GET", "POST", "PUT", "DELETE":
                    if case let .success(value) = result { self.body = value }
                case "DOWNLOAD":
                    self.body = self.downloadedBodyString()
                default:
                    break
                }
            }

            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }

        if let request = request as? DataRequest {
            request.responseString { response in
                requestComplete(response.response, response.result)
            }
        } else if let request = request as? DownloadRequest {
            request.responseString { response in
                requestComplete(response.response, response.result)
            }
        }
		print("<<< Exiting refresh()")
    }

    private func downloadedBodyString() -> String {
		print(">>> Entering downloadedBodyString()")
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
		print("downloadedBodyString(): cachesDirectory → \(cachesDirectory)")

        do {
            let contents = try fileManager.contentsOfDirectory(at: cachesDirectory,
                                                               includingPropertiesForKeys: nil,
                                                               options: .skipsHiddenFiles)

            if let fileURL = contents.first, let data = try? Data(contentsOf: fileURL) {
				print("downloadedBodyString(): fileURL → \(fileURL)")
				print("downloadedBodyString(): json → \(json)")
				print("downloadedBodyString(): prettyData → \(prettyData)")
                let json = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions())
                let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)

                if let prettyString = String(data: prettyData, encoding: String.Encoding.utf8) {
					print("downloadedBodyString(): prettyString → \(prettyString)")
                    try fileManager.removeItem(at: fileURL)
                    return prettyString
                }
            }
        } catch {
			print("Exception in downloadedBodyString(): \(error)")
            // No-op
        }

		print("<<< Exiting downloadedBodyString()")
        return ""
    }
}

// MARK: - UITableViewDataSource

extension DetailViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections(rawValue: section)! {
        case .headers:
            headers.count
        case .body:
            body == nil ? 0 : 1
        }
		print(">>> Entering tableView(tableView=\(tableView),indexPath=\(indexPath))")
		print("tableView(tableView=\(tableView),indexPath=\(indexPath)): cell → \(cell)")
		print("tableView(tableView=\(tableView),indexPath=\(indexPath)): field → \(field)")
		print("<<< Exiting tableView(tableView=\(tableView),indexPath=\(indexPath))")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Sections(rawValue: indexPath.section)! {
        case .headers:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Header")!
            let field = headers.keys.sorted(by: <)[indexPath.row]
            let value = headers[field]

            cell.textLabel?.text = field
            cell.detailTextLabel?.text = value

            return cell
        case .body:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Body")!
            cell.textLabel?.text = body

            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension DetailViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
		print(">>> Entering numberOfSections(tableView=\(tableView))")
        2
		print("<<< Exiting numberOfSections(tableView=\(tableView))")
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if self.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return ""
        }

        switch Sections(rawValue: section)! {
        case .headers:
            return "Headers"
        case .body:
            return "Body"
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Sections(rawValue: indexPath.section)! {
        case .body:
            300
        default:
            tableView.rowHeight
        }
		print(">>> Entering tableView(tableView=\(tableView),section=\(section))")
		print("tableView(tableView=\(tableView),section=\(section)): elapsedTimeText → \(elapsedTimeText)")
		print("<<< Exiting tableView(tableView=\(tableView),section=\(section))")
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if Sections(rawValue: section) == .body, let elapsedTime {
            let elapsedTimeText = DetailViewController.numberFormatter.string(from: elapsedTime as NSNumber) ?? "???"
            return "Elapsed Time: \(elapsedTimeText) sec"
        }

        return ""
    }
}
