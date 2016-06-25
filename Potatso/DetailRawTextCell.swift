//
//  DetailRawTextCell.swift
//  Potatso
//
//  Created by LEI on 4/27/16.
//  Copyright © 2016 TouchingApp. All rights reserved.
//

import Foundation
import Cartography

class RequestDetailBaseCell: UITableViewCell, RequestDetailCell {
    
    static let dateformatter: NSDateFormatter = {
        let f = NSDateFormatter()
        f.dateFormat = "yyyy-MM-dd hh:mm:ss.SSS"
        return f
    }()
    
    func config(request: Request, event: RequestEvent) {
        timeLabel.text = RequestDetailBaseCell.dateformatter.stringFromDate(NSDate(timeIntervalSince1970: event.timestamp))
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor.clearColor()
        contentView.addSubview(leftCircleView)
        contentView.addSubview(timeLabel)
        contentView.addSubview(backgroundWrapper)
        constrain(contentView, self) { contentView, superview in
            contentView.edges == superview.edges
        }
        leftCircleView.layer.cornerRadius = 4
        constrain(leftCircleView, timeLabel, backgroundWrapper, contentView) { leftCircleView, timeLabel, backgroundWrapper,  view in

            leftCircleView.centerX == view.leading + 15
            leftCircleView.width == 8
            leftCircleView.height == 8
            leftCircleView.top == view.top + 20
            
            timeLabel.centerY == leftCircleView.centerY
            timeLabel.leading == leftCircleView.trailing + 12
            timeLabel.trailing == view.trailing - 14

            backgroundWrapper.leading == timeLabel.leading
            backgroundWrapper.trailing == timeLabel.trailing
            backgroundWrapper.top == timeLabel.bottom + 8
            backgroundWrapper.bottom == view.bottom - 6
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var timeLabel: UILabel = {
        let v = UILabel()
        v.textColor = "808080".color
        v.font = UIFont.systemFontOfSize(10)
        return v
    }()
    
    lazy var leftCircleView: UIView = {
        let v = UIView()
        v.backgroundColor = "D1D1D1".color
        return v
    }()
    
    lazy var backgroundWrapper: UIView = {
        let v = UIView()
        v.backgroundColor = "FFFFFF".color
        v.layer.shadowColor = "AFAFAF".color.alpha(0.5).CGColor
        v.layer.shadowOffset = CGSize(width: 1, height: 1)
        return v
    }()
    
}

class RequestDetailRawTextCell: RequestDetailBaseCell {
    
    let group = ConstraintGroup()
    
    override func config(request: Request, event: RequestEvent) {
        super.config(request, event: event)
        var attr: NSMutableAttributedString?
        switch event.type {
        case .Init:
            attr = NSMutableAttributedString(string: "Start Request".localized(), attributes: [NSForegroundColorAttributeName: "34495E".color])
            attr?.appendAttributedString(NSAttributedString(string: "\n\n\(request.method.description) \(request.url)", attributes: [NSForegroundColorAttributeName: "2980B9".color]))
        case .DNS:
            attr = NSMutableAttributedString(string: "DNS Request".localized(), attributes: [NSForegroundColorAttributeName: "34495E".color])
            if event.duration > 0 {
                attr?.appendAttributedString(NSAttributedString(string: "\n\n\("Duration".localized()): \(String(format: "%d ms".localized(), Int(event.duration * 1000)))", attributes: [NSForegroundColorAttributeName: "2980B9".color]))
            }
        case .Remote:
            attr = NSMutableAttributedString(string: "Connection to remote".localized(), attributes: [NSForegroundColorAttributeName: "34495E".color])
            if event.duration > 0 {
                attr?.appendAttributedString(NSAttributedString(string: "\n\n\("Duration".localized()): \(String(format: "%d ms".localized(), Int(event.duration * 1000)))", attributes: [NSForegroundColorAttributeName: "2980B9".color]))
            }
        case .Open:
            attr = NSMutableAttributedString(string: "Connection established".localized(), attributes: [NSForegroundColorAttributeName: "34495E".color])
        case .Closed:
            attr = NSMutableAttributedString(string: "Request finished".localized(), attributes: [NSForegroundColorAttributeName: "34495E".color])
        }
        if let attr = attr {
            attr.addAttributes([NSFontAttributeName: UIFont.systemFontOfSize(15)], range: NSRange(location: 0, length: attr.length))
            let pStyle = NSMutableParagraphStyle()
            pStyle.lineBreakMode = .ByCharWrapping
            attr.addAttributes([NSParagraphStyleAttributeName: pStyle], range: NSRange(location: 0, length: attr.length))
            titleLabel.attributedText = attr
            let size = attr.boundingRectWithSize(CGSize(width: UIScreen.mainScreen().bounds.width - 51, height: 10000), options: NSStringDrawingOptions.UsesLineFragmentOrigin, context: nil)
            constrain(titleLabel, backgroundWrapper, replace: group) { titleLabel, backgroundWrapper in
                titleLabel.height == ceil(size.height)
                titleLabel.edges == inset(backgroundWrapper.edges, 10)
            }
        }
        
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(titleLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    lazy var titleLabel: UITextView = {
        let v = UITextView()
        v.textContainerInset = UIEdgeInsetsZero
        v.textContainer.lineFragmentPadding = 0
        v.editable = false
        v.scrollEnabled = false
        return v
    }()
    
}