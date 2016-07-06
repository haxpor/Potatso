//
//  CollectionViewController.swift
//  Potatso
//
//  Created by LEI on 5/31/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography

private let rowHeight: CGFloat = 135

class CollectionViewController: UIViewController {

    var pageViewControllers: [UIViewController] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = segmentedControl
        pageViewControllers.append(RuleSetListViewController())
        pageViewControllers.append(ProxyListViewController())
        pageViewControllers.append(CloudViewController())
        showCollection(0)
    }

    func onSegmentedChanged(seg: UISegmentedControl) {
        showCollection(seg.selectedSegmentIndex)
    }

    func showCollection(index: Int) {
        if index < 2 {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(add))
        }else {
            navigationItem.rightBarButtonItem = nil
        }
        segmentedControl.selectedSegmentIndex = index
        if index < pageViewControllers.count {
            pageVC.setViewControllers([pageViewControllers[index]], direction: .Forward, animated: false, completion: nil)
        }
    }

    func add() {
        switch segmentedControl.selectedSegmentIndex {
        case 0:
            let vc = RuleSetConfigurationViewController(ruleSet: nil)
            navigationController?.pushViewController(vc, animated: true)
        case 1:
            let vc = ProxyConfigurationViewController(upstreamProxy: nil)
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = Color.Background
        addChildVC(pageVC)
        setupAutoLayout()
    }

    func setupAutoLayout() {
        constrain(pageVC.view, view) { pageView, superview in
            pageView.edges == superview.edges
        }
    }


    lazy var pageVC: UIPageViewController = {
        let p = UIPageViewController(transitionStyle: .Scroll, navigationOrientation: .Horizontal, options: nil)
        return p
    }()

    lazy var segmentedControl: UISegmentedControl = {
        let v = UISegmentedControl(items: ["Rule Set".localized(), "Proxy".localized(), "Cloud Set".localized()])
        v.addTarget(self, action: #selector(CollectionViewController.onSegmentedChanged(_:)), forControlEvents: .ValueChanged)
        return v
    }()

}