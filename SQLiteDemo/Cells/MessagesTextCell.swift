import Foundation
import TinyConstraints
import UIKit

class MessagesTextCell: UITableViewCell {
    var isOutgoingMessage: Bool = false {
        didSet {
            self.bubbleView.backgroundColor = self.isOutgoingMessage ? #colorLiteral(red: 0.02588345483, green: 0.7590896487, blue: 0.2107430398, alpha: 1) : #colorLiteral(red: 0.9254434109, green: 0.925465405, blue: 0.9339957833, alpha: 1)
            self.textView.textColor = self.isOutgoingMessage ? .white : .black
            self.textView.backgroundColor = self.bubbleView.backgroundColor
        }
    }
    var avatar: UIImage? {
        didSet {
            self.avatarImageView.image = self.avatar

            self.avatarImageView.isHidden = self.avatar == nil
        }
    }

    var messageBody: String = "" {
        didSet {
            self.textView.text = self.messageBody

            self.textViewHeight.isActive = self.messageBody.isEmpty
            self.textViewTopMargin.constant = self.messageBody.isEmpty ? 0 : 8
            self.textViewBottomMargin.constant = self.messageBody.isEmpty ? 0 : -8
        }
    }

    var messageImage: UIImage? {
        didSet {
            self.messageImageView.image = self.messageImage

            self.imageViewHeight.isActive = false
            self.imageViewAspectRatio.isActive = false

            if let image = self.messageImage {
                let aspectRatio: CGFloat = image.size.height / image.size.width
                self.imageViewAspectRatio = self.messageImageView.heightAnchor.constraint(equalTo: self.messageImageView.widthAnchor, multiplier: aspectRatio)
                self.imageViewAspectRatio.isActive = true

                self.imageViewHeight = self.messageImageView.heightAnchor.constraint(lessThanOrEqualTo: self.bubbleView.widthAnchor, multiplier: 1.0)
                self.imageViewHeight.isActive = true
            } else {
                self.imageViewAspectRatio.isActive = false
                self.imageViewHeight = self.messageImageView.heightAnchor.constraint(equalToConstant: 0)
                self.imageViewHeight.isActive = true
            }
        }
    }

    private lazy var textViewBottomMargin: NSLayoutConstraint = {
        return self.textView.bottomAnchor.constraint(equalTo: self.bubbleView.bottomAnchor, constant: -8)
    }()

    private lazy var textViewTopMargin: NSLayoutConstraint = {
        return self.textView.topAnchor.constraint(equalTo: self.messageImageView.bottomAnchor, constant: 8)
    }()

    private lazy var imageViewAspectRatio: NSLayoutConstraint = {
        return self.messageImageView.heightAnchor.constraint(equalTo: self.messageImageView.widthAnchor, multiplier: 1.0)
    }()

    private lazy var imageViewHeight: NSLayoutConstraint = {
        return self.messageImageView.heightAnchor.constraint(lessThanOrEqualTo: self.bubbleView.widthAnchor, multiplier: 1.0)
    }()

    private lazy var textViewHeight: NSLayoutConstraint = {
        return self.textView.heightAnchor.constraint(equalToConstant: 0)
    }()

    private lazy var messageImageView: UIImageView = {
        let view = UIImageView(withAutoLayout: true)

        return view
    }()

    private lazy var errorLabel: UILabel = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let attributes: [NSAttributedStringKey: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.red
        ]

        let boldAttributes: [NSAttributedStringKey: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.red
        ]

        let attributedString = NSMutableAttributedString(string: "Localized.messages_sent_error", attributes: attributes)
        attributedString.addAttributes(boldAttributes, range: NSRange(location: 0, length: 13))

        let view = UILabel(withAutoLayout: true)
        view.alpha = 0
        view.attributedText = attributedString
        view.adjustsFontForContentSizeCategory = true
        view.numberOfLines = 1

        return view
    }()

    private lazy var textView: UITextView = {
        let view = UITextView(withAutoLayout: true)
        view.font = .systemFont(ofSize: 18)
        view.adjustsFontForContentSizeCategory = true
        view.dataDetectorTypes = [.link]
        view.isUserInteractionEnabled = true
        view.isScrollEnabled = false
        view.isEditable = false
        view.contentMode = .topLeft
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.maximumNumberOfLines = 0

        view.linkTextAttributes = [NSAttributedStringKey.underlineStyle.rawValue: NSUnderlineStyle.styleSingle.rawValue]

        view.setContentHuggingPriority(.required, for: .vertical)

        return view
    }()

    private lazy var bubbleView: UIView = {
        let view = UIView(withAutoLayout: true)
        view.layer.cornerRadius = 8
        view.clipsToBounds = true

        return view
    }()

    private lazy var containerView: UIView = {
        let view = UIView(withAutoLayout: true)

        return view
    }()

    private lazy var avatarImageView: UIImageView = {
        let view = UIImageView(withAutoLayout: true)
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 22
        view.isUserInteractionEnabled = true
        view.layer.borderColor = UIColor.gray.cgColor
        view.layer.borderWidth = 1.0 / UIScreen.main.scale

        return view
    }()

    private lazy var errorView: MessagesErrorView = {
        let view = MessagesErrorView(withAutoLayout: true)
        view.alpha = 0

        return view
    }()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.backgroundColor = nil
        self.selectionStyle = .none
        self.contentView.autoresizingMask = [.flexibleHeight]

        self.contentView.addSubview(self.containerView)
        self.containerView.fillSuperview()

        self.containerView.addSubview(self.bubbleView)
        self.containerView.addSubview(self.avatarImageView)
        //        self.containerView.addSubview(self.errorView)

        self.bubbleView.addSubview(self.messageImageView)
        self.bubbleView.addSubview(self.textView)

        self.avatarImageView.set(height: 44)
        self.avatarImageView.set(width: 44)
        self.avatarImageView.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor, constant: -8).isActive = true
        self.avatarImageView.leftAnchor.constraint(equalTo: self.containerView.leftAnchor, constant: 8).isActive = true

        //        self.errorView.set(height: 24)
        //        self.errorView.set(width: 24)
        //        self.errorView.rightAnchor.constraint(equalTo: self.containerView.rightAnchor, constant: 9).isActive = true
        //        self.errorView.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor, constant: -8).isActive = true
        //        self.errorView.topAnchor.constraintEqualToSystemSpacingBelow(self.containerView.topAnchor, multiplier: 1.0).isActive = true

        self.bubbleView.leftAnchor.constraint(equalTo: self.avatarImageView.rightAnchor, constant: 8).isActive = true
        self.bubbleView.topAnchor.constraint(equalTo: self.containerView.topAnchor, constant: 8).isActive = true
        self.bubbleView.rightAnchor.constraint(equalTo: self.containerView.rightAnchor, constant: -8).isActive = true
        self.bubbleView.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor, constant: -8).isActive = true

        var constraints = NSLayoutConstraint.constraints(withVisualFormat: "|[image]|", options: [], metrics: [:], views: ["image" : self.messageImageView])
        constraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "|-[text]-|", options: [], metrics: [:], views: ["text": self.textView]))
        constraints.append(contentsOf: [self.textViewHeight, self.imageViewAspectRatio, self.imageViewHeight, self.textViewBottomMargin, self.textViewTopMargin])

        self.messageImageView.topAnchor.constraint(equalTo: self.bubbleView.topAnchor, constant: 0).isActive = true

        NSLayoutConstraint.activate(constraints)

        self.textViewHeight.constant = 0
        self.textView.textContainerInset = .zero
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class MessagesErrorView: UIView {
    private lazy var imageView: UIImageView = {
        let view = UIImageView(withAutoLayout: true)
        view.image = #imageLiteral(resourceName: "error")
        view.contentMode = .scaleAspectFit

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.imageView)

        self.imageView.set(height: 24)
        self.imageView.set(width: 24)
        self.imageView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 6).isActive = true
        self.imageView.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 0).isActive = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
