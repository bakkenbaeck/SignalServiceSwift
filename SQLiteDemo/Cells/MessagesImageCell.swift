import Foundation
import UIKit
import TinyConstraints

class MessagesImageCell: MessagesBasicCell {

    static let reuseIdentifier = "MessagesImageCell"

    var messageImage: UIImage? {
        didSet {
            guard let messageImage = self.messageImage else {
                self.heightConstraint?.isActive = false
                self.heightConstraint = nil

                return
            }

            self.messageImageView.image = messageImage

            let aspectRatio: CGFloat = messageImage.size.height / messageImage.size.width

            self.heightConstraint?.isActive = false
            self.heightConstraint = self.messageImageView.height(to: self.messageImageView, self.messageImageView.widthAnchor, multiplier: aspectRatio, priority: .defaultHigh)
        }
    }

    private(set) lazy var messageImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit

        return view
    }()

    private var heightConstraint: NSLayoutConstraint?

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.messageImageView.edges(to: self.bubbleView)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        self.messageImageView.image = nil
    }
}
