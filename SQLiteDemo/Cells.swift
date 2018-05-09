//
//  Cells.swift
//  Demo
//
//  Created by Igor Ranieri on 17.04.18.
//  Copyright © 2018 Bakken&Bæck. All rights reserved.
//

import UIKit

class ChatCell: UITableViewCell {
    var date: String = "" {
        didSet {
            self.dateLabel.text = date
        }
    }

    var state: UIColor? {
        set {
            self.stateView.backgroundColor = newValue
        }
        get {
            return self.stateView.backgroundColor
        }
    }

    var avatarImage: UIImage? {
        didSet {
            self.avatarImageView.image = self.avatarImage
        }
    }

    var contentBackgroundColor: UIColor {
        didSet {
            self.containerView.backgroundColor = self.contentBackgroundColor
        }
    }

    var alignment: NSTextAlignment {
        get {
            return self.titleLabel.textAlignment
        }
        set {
            self.titleLabel.textAlignment = newValue
            self.dateLabel.textAlignment = newValue
        }
    }

    var titleColor: UIColor {
        get {
            return self.titleLabel.textColor
        }
        set {
            self.titleLabel.textColor = newValue
            self.dateLabel.textColor = newValue
        }
    }

    private lazy var containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    private lazy var stateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()


    private lazy var avatarImageView: UIImageView = {
        let view = UIImageView(image: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit

        return view
    }()

    private lazy var dateLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .right

        return label
    }()

    var title: String? {
        didSet {
            self.titleLabel.text = self.title
        }
    }

    fileprivate lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        return label
    }()

    override func setSelected(_ selected: Bool, animated: Bool) {
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
    }

    func setup() {
        self.contentView.addSubview(self.containerView)

        self.containerView.addSubview(self.avatarImageView)

        self.containerView.addSubview(self.titleLabel)
        self.containerView.addSubview(self.dateLabel)
        self.containerView.addSubview(self.stateView)

        self.containerView.layer.masksToBounds = true
        self.containerView.layer.cornerRadius = 16

        self.avatarImageView.layer.cornerRadius = 22

        NSLayoutConstraint.activate([
            self.containerView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 8),
            self.containerView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -8),
            self.containerView.leftAnchor.constraint(equalTo: self.contentView.leftAnchor, constant: 8),
            self.containerView.rightAnchor.constraint(equalTo: self.contentView.rightAnchor, constant: -8),

            self.avatarImageView.topAnchor.constraint(equalTo: self.containerView.topAnchor),
            self.avatarImageView.leftAnchor.constraint(equalTo: self.containerView.leftAnchor),
            self.avatarImageView.rightAnchor.constraint(equalTo: self.containerView.rightAnchor),

            self.avatarImageView.heightAnchor.constraint(equalToConstant: 44),
            self.avatarImageView.widthAnchor.constraint(equalToConstant: 44),

            self.titleLabel.topAnchor.constraint(equalTo: self.avatarImageView.bottomAnchor, constant: 8),
            self.titleLabel.leftAnchor.constraint(equalTo: self.containerView.leftAnchor, constant: 8),
            self.titleLabel.rightAnchor.constraint(equalTo: self.containerView.rightAnchor, constant: -8),
            self.titleLabel.bottomAnchor.constraint(equalTo: self.dateLabel.topAnchor, constant: -8),

            self.stateView.topAnchor.constraint(equalTo: self.dateLabel.topAnchor),
            self.stateView.rightAnchor.constraint(equalTo: self.containerView.rightAnchor),
            self.stateView.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor),

            self.dateLabel.leftAnchor.constraint(equalTo: self.containerView.leftAnchor, constant: 8),
            self.dateLabel.rightAnchor.constraint(equalTo: self.stateView.leftAnchor, constant: -8),
            self.dateLabel.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor, constant: -8)
        ])

//        constraints.forEach { constraint in
//            constraint.priority = UILayoutPriority.init(rawValue: 999.0)
//            constraint.isActive = true
//        }
    }

    init() {
        self.contentBackgroundColor = .clear
        super.init(style: .default, reuseIdentifier: nil)

        self.setup()
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        self.contentBackgroundColor = .clear

        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        self.contentBackgroundColor = .clear

        super.init(coder: aDecoder)

        self.setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        self.avatarImage = nil
        self.title = nil
        self.date = ""
        self.state = .clear
        self.containerView.backgroundColor = self.backgroundColor
    }
}
