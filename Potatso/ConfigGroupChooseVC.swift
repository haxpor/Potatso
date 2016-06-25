//
//  ConfigGroupChooseVC.swift
//  Potatso
//
//  Created by LEI on 5/27/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography
import PotatsoModel
import RealmSwift
import PotatsoLibrary

private let kGroupCellIdentifier = "group"

private let rowHeight: CGFloat = 110

class ConfigGroupChooseManager {

    static let shared = ConfigGroupChooseManager()

    var window: UIWindow?
    var chooseVC: ConfigGroupChooseVC?

    let screenHeight = UIScreen.mainScreen().bounds.height
    let screenWidth = UIScreen.mainScreen().bounds.width

    func show() {
        if window == nil {
            window = UIWindow(frame: UIScreen.mainScreen().bounds)
            window?.backgroundColor = "000".color.alpha(0.5)
            window?.makeKeyAndVisible()
            chooseVC = ConfigGroupChooseVC()
            window?.addSubview(chooseVC!.view)
            chooseVC!.view.frame = CGRect(x: 0, y: screenHeight, width: screenWidth, height: screenHeight)
            UIView.animateWithDuration(0.3) {
                self.chooseVC!.view.frame.origin = CGPoint(x: 0, y: 0)
            }
        }
    }

    func hide() {
        if let vc = chooseVC {
            UIView.animateWithDuration(0.3, animations: {
                vc.view.frame.origin = CGPoint(x: 0, y: self.screenHeight)
            }, completion: { (finished) in
                vc.view.removeFromSuperview()
                self.chooseVC = nil
                self.window?.hidden = true
                self.window = nil
            })
        }
    }

}

class ConfigGroupChooseVC: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var groups: [ConfigurationGroup]
    let colors = ["3498DB", "E74C3C", "8E44AD", "16A085", "E67E22", "2C3E50"]
    var gesture: UITapGestureRecognizer?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        groups = defaultRealm.objects(ConfigurationGroup).sorted("createAt").map { $0 }
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(onVPNStatusChanged), name: kProxyServiceVPNStatusNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
    }

    func onVPNStatusChanged() {
        updateUI()
    }

    func updateUI() {
        tableView.reloadData()
    }

    func showConfigGroup(group: ConfigurationGroup, animated: Bool = true) {
        CurrentGroupManager.shared.group = group
        ConfigGroupChooseManager.shared.hide()
    }

    func onTap() {
        ConfigGroupChooseManager.shared.hide()
    }

    func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        if let view = touch.view where view.isDescendantOfView(tableView){
            return false
        }
        return true
    }

    // MARK: - TableView DataSource & Delegate
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(kGroupCellIdentifier, forIndexPath: indexPath) as! ConfigGroupCell
        cell.config(groups[indexPath.row], hintColor: colors[indexPath.row % colors.count].color )
        return cell
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        showConfigGroup(groups[indexPath.row])
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return groups.count > 1
    }

    func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return .Delete
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let item: ConfigurationGroup
            guard indexPath.row < groups.count else {
                return
            }
            item = groups[indexPath.row]
            tableView.beginUpdates()
            defer {
                tableView.endUpdates()
            }
            do {
                groups.removeAtIndex(indexPath.row)
                try defaultRealm.write {
                    defaultRealm.delete(item)
                }
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
            }catch {
                self.showTextHUD("\("Fail to delete item".localized()): \((error as NSError).localizedDescription)", dismissAfterDelay: 1.5)
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let tableRowHeight = CGFloat(groups.count) * rowHeight
        let maxHeight = view.bounds.size.height * 0.7
        let height = min(tableRowHeight, maxHeight)
        let originY = view.bounds.size.height - height
        tableView.scrollEnabled = (tableRowHeight > maxHeight)
        tableView.frame = CGRect(x: 0, y: originY, width: view.bounds.size.width, height: height)
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = UIColor.clearColor()
        gesture = UITapGestureRecognizer(target: self, action: #selector(onTap))
        gesture?.delegate = self
        view.addGestureRecognizer(gesture!)
        view.addSubview(tableView)
        tableView.registerClass(ConfigGroupCell.self, forCellReuseIdentifier: kGroupCellIdentifier)
    }

    lazy var tableView: UITableView = {
        let v = UITableView(frame: CGRect.zero, style: .Plain)
        v.dataSource = self
        v.delegate = self
        v.tableFooterView = UIView()
        v.tableHeaderView = UIView()
        v.separatorStyle = .SingleLine
        v.rowHeight = rowHeight
        return v
    }()

}