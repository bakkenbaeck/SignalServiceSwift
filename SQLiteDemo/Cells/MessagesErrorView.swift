import Foundation
import TinyConstraints
import UIKit

final class MessagesErrorView: UIView {

    private lazy var imageView: UIImageView = {
        let view = UIImageView()
        view.image = #imageLiteral(resourceName: "error")
        view.contentMode = .scaleAspectFit

        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.addSubview(self.imageView)

        self.imageView.size(CGSize(width: 24, height: 24))
        self.imageView.left(to: self, offset: 6)
        self.imageView.centerY(to: self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
