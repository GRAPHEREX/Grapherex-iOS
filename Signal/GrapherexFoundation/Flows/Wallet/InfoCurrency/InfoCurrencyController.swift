//
//  Copyright (c) 2020 SkyTech. All rights reserved.
// 

import Foundation

final class InfoCurrencyController: ActionSheetController{
    
    var wallet: Wallet!
    
    override func setup() {
        super.setup()
        
        isCancelable = true
        setupCenterHeader(title: NSLocalizedString("MAIN_INFO", comment: ""), close: #selector(close))
        makeHeader()
        stackView.spacing = 16
        setupMargins(margin: 16)

        makeView(title: NSLocalizedString("MAIN_SYMBOL", comment: ""), subtitle: wallet.currency.symbol)
        makeView(title: NSLocalizedString("MAIN_CHAIN", comment: ""), subtitle: wallet.currency.name)
        makeView(title: NSLocalizedString("MAIN_ADDRESS", comment: ""), subtitle: wallet.address)
    }
    
}

fileprivate extension InfoCurrencyController {
    func makeHeader() {
        let imageView = UIImageView()
        imageView.sd_setImage(with: URL(string: wallet.currency.icon), completed: nil)
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimension(.height, toSize: 64)
        stackView.addArrangedSubview(imageView)
        
        let titleLabel = UILabel()
        titleLabel.textColor = Theme.primaryTextColor
        titleLabel.font = UIFont.st_robotoRegularFont(withSize: 18).ows_semibold
        titleLabel.textAlignment = .center
        titleLabel.text = wallet.currency.name
        stackView.addArrangedSubview(titleLabel)
    }
    
    func makeView(title: String, subtitle: String, errorMessage: String? = nil) {
        let backgroundView = UIView()
        backgroundView.backgroundColor = Theme.backgroundColor
        
        let titleLabel = UILabel()
        titleLabel.textColor = Theme.secondaryTextAndIconColor
        titleLabel.font = UIFont.st_robotoRegularFont(withSize: 14)
        titleLabel.text = title
        
        backgroundView.addSubview(titleLabel)
        titleLabel.autoPinEdge(.top, to: .top, of: backgroundView, withOffset: 4)
        titleLabel.autoPinEdge(.leading, to: .leading, of: backgroundView)
        titleLabel.autoPinEdge(.trailing, to: .trailing, of: backgroundView)
        
        let subtitleLabel = UILabel()
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textColor = Theme.primaryTextColor
        subtitleLabel.font = UIFont.st_robotoRegularFont(withSize: 16).ows_semibold
        subtitleLabel.text = subtitle
        
        backgroundView.addSubview(subtitleLabel)
        subtitleLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 8)
        subtitleLabel.autoPinEdge(.leading, to: .leading, of: backgroundView)
        subtitleLabel.autoPinEdge(.trailing, to: .trailing, of: backgroundView)
        
        let attentionLabel = UILabel()
        attentionLabel.textColor = .st_otherRed
        attentionLabel.font = UIFont.st_robotoRegularFont(withSize: 12).ows_semibold
        attentionLabel.text = errorMessage
        
        backgroundView.addSubview(attentionLabel)
        attentionLabel.autoPinEdge(.top, to: .bottom, of: subtitleLabel, withOffset: 4)
        attentionLabel.autoPinEdge(.leading, to: .leading, of: backgroundView)
        attentionLabel.autoPinEdge(.trailing, to: .trailing, of: backgroundView)
        attentionLabel.autoPinEdge(.bottom, to: .bottom, of: backgroundView)
        
        stackView.addArrangedSubview(backgroundView)
    }
    
    @objc
    func close() {
        self.dismiss(animated: true, completion:  nil)
    }
}
