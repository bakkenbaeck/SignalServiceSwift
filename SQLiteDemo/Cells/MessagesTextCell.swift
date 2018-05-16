import Foundation
import TinyConstraints
import UIKit

class MessagesTextCell: MessagesBasicCell {

    static let reuseIdentifier = "MessagesTextCell"

    var messageText: String? {
        didSet {
            self.textView.text = self.messageText
            self.textView.textColor = self.messageColor
        }
    }

    var messageImage: UIImage? {
        didSet {
            guard let messageImage = self.messageImage else {
                self.imageHeightConstraint?.isActive = false
                self.imageHeightConstraint = nil

                return
            }

            self.messageImageView.image = messageImage

            let aspectRatio: CGFloat = messageImage.size.height / messageImage.size.width
            let widthAnchor = messageImage.size.width > self.bubbleView.frame.width ? self.bubbleView.widthAnchor : self.messageImageView.widthAnchor

            self.imageHeightConstraint?.isActive = false
            self.imageHeightConstraint = self.messageImageView.heightAnchor.constraint(equalTo: widthAnchor, multiplier: aspectRatio)
            self.imageHeightConstraint?.isActive = true
        }
    }

    private(set) lazy var messageImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit

        return view
    }()

    private var imageHeightConstraint: NSLayoutConstraint?

    private var messageColor: UIColor {
        return self.isOutGoing ? .black : .white
    }

    private lazy var textView: UITextView = {
        let view = UITextView()

        view.font = .systemFont(ofSize: 18)
        view.adjustsFontForContentSizeCategory = true
        view.dataDetectorTypes = [.link]
        view.isUserInteractionEnabled = true
        view.isScrollEnabled = false
        view.isEditable = false
        view.backgroundColor = .clear
        view.contentMode = .topLeft
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.maximumNumberOfLines = 0

        view.linkTextAttributes = [NSAttributedStringKey.underlineStyle.rawValue: NSUnderlineStyle.styleSingle.rawValue]

        return view
    }()

    override var isOutGoing: Bool {
        didSet {
            super.isOutGoing = self.isOutGoing

            self.textView.textColor = self.isOutGoing ? .white : .black
            self.bubbleView.backgroundColor = isOutGoing ? .green : .blue
        }
    }

    override func showSentError(_ show: Bool, animated: Bool) {
        super.showSentError(show, animated: animated)
        self.textView.isUserInteractionEnabled = !show
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.bubbleView.addSubview(self.textView)
        self.bubbleView.addSubview(self.messageImageView)

        self.messageImageView.edgesToSuperview(excluding: .bottom)
        self.messageImageView.bottomToTop(of: self.textView, offset: -8)

        self.textView.setHugging(.required, for: .vertical)
        self.textView.edgesToSuperview(excluding: .top, insets: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: -12))
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        if let text = self.textView.attributedText?.mutableCopy() as? NSMutableAttributedString {
            let range = NSRange(location: 0, length: text.string.count)

            text.removeAttribute(.link, range: range)
            text.removeAttribute(.foregroundColor, range: range)
            text.removeAttribute(.underlineStyle, range: range)

            self.textView.attributedText = text
        }

        self.textView.adjustsFontForContentSizeCategory = true
        self.textView.text = nil
        self.messageImage = nil
    }
}
