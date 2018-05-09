import Foundation
import UIKit
import SignalServiceSwift

enum MessagePositionType {
    case single
    case top
    case middle
    case bottom
}

protocol MessagesBasicCellDelegate: class {
    func didTapAvatarImageView(from cell: MessagesBasicCell)
}

/* Messages Basic Cell:
 This UITableViewCell is the base cell for the different
 advanced cells used in messages. It provides the ground layout. */

class MessagesBasicCell: UITableViewCell {

    private let contentLayoutGuide = UILayoutGuide()
    private let leftLayoutGuide = UILayoutGuide()
    private let centerLayoutGuide = UILayoutGuide()
    private let rightLayoutGuide = UILayoutGuide()
    private let bottomLayoutGuide = UILayoutGuide()

    private(set) var leftWidthConstraint: NSLayoutConstraint?
    private(set) var rightWidthConstraint: NSLayoutConstraint?

    private(set) lazy var bubbleView: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.layer.cornerRadius = 8

        return view
    }()

    private(set) lazy var avatarImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 18
        view.isUserInteractionEnabled = true

        return view
    }()

    private(set) lazy var errorView: MessagesErrorView = {
        let view = MessagesErrorView()
        view.alpha = 0

        return view
    }()

    private(set) lazy var errorlabel: UILabel = {

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

        let view = UILabel()
        view.alpha = 0
        view.attributedText = attributedString
        view.adjustsFontForContentSizeCategory = true
        view.numberOfLines = 1

        return view
    }()

    private let margin: CGFloat = 10
    private let avatarRadius: CGFloat = 44

    private var bubbleLeftConstraint: NSLayoutConstraint?
    private var bubbleRightConstraint: NSLayoutConstraint?
    private var bubbleLeftConstantConstraint: NSLayoutConstraint?
    private var bubbleRightConstantConstraint: NSLayoutConstraint?
    private var contentLayoutGuideTopConstraint: NSLayoutConstraint?
    private var bottomLayoutGuideHeightConstraint: NSLayoutConstraint?

    private lazy var avatarTapGestureRecogniser: UITapGestureRecognizer = {
        UITapGestureRecognizer(target: self, action: #selector(didTapAvatarImageView(_:)))
    }()

    weak var delegate: MessagesBasicCellDelegate?

    var isOutGoing: Bool = false {
        didSet {
            if self.isOutGoing {
                self.bubbleRightConstraint?.isActive = false
                self.bubbleLeftConstantConstraint?.isActive = false
                self.bubbleLeftConstraint?.isActive = true
                self.bubbleRightConstantConstraint?.isActive = true
            } else {
                self.bubbleLeftConstraint?.isActive = false
                self.bubbleRightConstantConstraint?.isActive = false
                self.bubbleRightConstraint?.isActive = true
                self.bubbleLeftConstantConstraint?.isActive = true
            }
        }
    }

    var positionType: MessagePositionType = .single {
        didSet {
            let isFirstMessage = self.positionType == .single || self.positionType == .top
            self.contentLayoutGuideTopConstraint?.constant = isFirstMessage ? 8 : 4

            let isAvatarHidden = self.positionType == .middle || self.positionType == .top || self.isOutGoing
            self.avatarImageView.isHidden = isAvatarHidden
        }
    }

    var sentState: OutgoingSignalMessage.MessageState = .attemptingOut {
        didSet {
            switch self.sentState {
            case .none, .sent, .attemptingOut:
                self.showSentError(false)
            case .unsent:
                self.showSentError(true)
            }
        }
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.backgroundColor = nil
        self.selectionStyle = .none
        self.contentView.autoresizingMask = [.flexibleHeight]

        /* Layout Guides:
         The leftLayoutGuide reserves space for an optional avatar.
         The centerLayoutGuide defines the space for the message content.
         The rightLayoutGuide reserves space for an optional error indicator.
         */
        [self.contentLayoutGuide, self.leftLayoutGuide, self.centerLayoutGuide, self.rightLayoutGuide, self.bottomLayoutGuide].forEach {
            self.contentView.addLayoutGuide($0)
        }

        self.contentLayoutGuideTopConstraint = self.contentLayoutGuide.top(to: self.contentView, offset: 2)
        self.contentLayoutGuide.left(to: self.contentView)
        self.contentLayoutGuide.right(to: self.contentView)
        self.contentLayoutGuide.width(UIScreen.main.bounds.width)

        self.leftLayoutGuide.top(to: self.contentLayoutGuide)
        self.leftLayoutGuide.left(to: self.contentLayoutGuide, offset: self.margin)
        self.leftLayoutGuide.bottom(to: self.contentLayoutGuide)

        self.centerLayoutGuide.top(to: self.contentLayoutGuide)
        self.centerLayoutGuide.leftToRight(of: self.leftLayoutGuide)
        self.centerLayoutGuide.bottom(to: self.contentLayoutGuide)

        self.rightLayoutGuide.top(to: self.contentLayoutGuide)
        self.rightLayoutGuide.leftToRight(of: self.centerLayoutGuide)
        self.rightLayoutGuide.bottom(to: self.contentLayoutGuide)
        self.rightLayoutGuide.right(to: self.contentLayoutGuide, offset: -self.margin)

        self.leftWidthConstraint = self.leftLayoutGuide.width(self.avatarRadius)
        self.rightWidthConstraint = self.rightLayoutGuide.width(0)

        self.bottomLayoutGuide.topToBottom(of: self.contentLayoutGuide)
        self.bottomLayoutGuide.left(to: self.contentView, offset: 10)
        self.bottomLayoutGuide.bottom(to: self.contentView)
        self.bottomLayoutGuide.right(to: self.contentView, offset: -10)

        self.bottomLayoutGuideHeightConstraint = self.bottomLayoutGuide.height(0)

        /* Avatar Image View:
         A UIImageView for showing an optional avatar of the user. */

        self.contentView.addSubview(self.avatarImageView)
        self.avatarImageView.left(to: self.leftLayoutGuide)
        self.avatarImageView.bottom(to: self.leftLayoutGuide)
        self.avatarImageView.right(to: self.leftLayoutGuide, offset: -8)
        self.avatarImageView.height(to: self.avatarImageView, self.avatarImageView.widthAnchor)

        /* Bubble View:
         The container that can be filled with a message, image or
         even a payment request. */

        self.contentView.addSubview(self.bubbleView)
        self.bubbleView.top(to: self.centerLayoutGuide)
        self.bubbleView.bottom(to: self.centerLayoutGuide)

        self.bubbleLeftConstraint = self.bubbleView.left(to: self.centerLayoutGuide, offset: 50, relation: .equalOrGreater)
        self.bubbleRightConstraint = self.bubbleView.right(to: self.centerLayoutGuide, offset: -50, relation: .equalOrLess)
        self.bubbleLeftConstantConstraint = self.bubbleView.left(to: self.centerLayoutGuide, isActive: false)
        self.bubbleRightConstantConstraint = self.bubbleView.right(to: self.centerLayoutGuide, isActive: false)

        /*
         Error State:
         A red view that can animate in from the right to indicate that a
         message has failed to sent and a label that informs the user.
         */

        self.contentView.addSubview(self.errorView)
        self.errorView.edges(to: self.rightLayoutGuide)

        self.contentView.addSubview(self.errorlabel)
        self.errorlabel.edges(to: self.bottomLayoutGuide)

        self.avatarImageView.addGestureRecognizer(self.avatarTapGestureRecogniser)
    }

    func showSentError(_ show: Bool, animated: Bool = false) {
        self.rightWidthConstraint?.constant = show ? 30 : 0
        self.bottomLayoutGuideHeightConstraint?.constant = show ? 30 : 0

        if animated {
            UIView.animate(withDuration: 1, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .curveEaseOut, animations: {
                self.errorView.alpha = show ? 1 : 0
                self.errorlabel.alpha = show ? 1 : 0

                if self.superview != nil {
                    self.layoutIfNeeded()
                }
            }, completion: nil)
        } else {
            self.errorView.alpha = show ? 1 : 0
            self.errorlabel.alpha = show ? 1 : 0

            if self.superview != nil {
                self.layoutIfNeeded()
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        self.avatarImageView.image = nil
        self.sentState = .none
        self.isUserInteractionEnabled = true
    }

    @objc private func didTapAvatarImageView(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }

        self.delegate?.didTapAvatarImageView(from: self)
    }
}
