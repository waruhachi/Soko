import Preferences
import UIKit

@objc(SokoTextCellWithIcon)
final class TextCellWithIcon: PSTableCell {
	private var symbolView: UIImageView?
	private var iconTitleLabel: UILabel?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		setUpContent()
	}

	override init(
		style: UITableViewCell.CellStyle, reuseIdentifier: String?, specifier: PSSpecifier?
	) {
		super.init(style: style, reuseIdentifier: reuseIdentifier, specifier: specifier)
		setUpContent()
		configure(with: specifier)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setUpContent()
		configure(with: specifier)
	}

	private func setUpContent() {
		guard symbolView == nil else { return }

		selectionStyle = .none
		backgroundColor = .clear

		let symbolView = UIImageView()
		self.symbolView = symbolView
		symbolView.translatesAutoresizingMaskIntoConstraints = false
		symbolView.contentMode = .scaleAspectFit
		symbolView.tintColor = .systemBlue
		symbolView.isAccessibilityElement = false
		contentView.addSubview(symbolView)

		let iconTitleLabel = UILabel()
		self.iconTitleLabel = iconTitleLabel
		iconTitleLabel.translatesAutoresizingMaskIntoConstraints = false
		iconTitleLabel.font = .systemFont(ofSize: 17, weight: .regular)
		iconTitleLabel.textColor = .label
		contentView.addSubview(iconTitleLabel)

		NSLayoutConstraint.activate([
			symbolView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
			symbolView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			symbolView.widthAnchor.constraint(equalToConstant: 26),
			symbolView.heightAnchor.constraint(equalToConstant: 26),
			iconTitleLabel.leadingAnchor.constraint(
				equalTo: symbolView.trailingAnchor, constant: 12),
			iconTitleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
			iconTitleLabel.trailingAnchor.constraint(
				lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
		])

		hideSystemLabels()
	}

	override func refreshCellContents(with specifier: PSSpecifier?) {
		super.refreshCellContents(with: specifier)
		configure(with: specifier)
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		hideSystemLabels()
	}

	private func configure(with specifier: PSSpecifier?) {
		let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
		let symbolName = specifier?.properties["sfIcon"] as? String ?? "arrow.up.and.down"
		symbolView?.image = UIImage(systemName: symbolName, withConfiguration: configuration)
		iconTitleLabel?.text = specifier?.properties["label"] as? String
		hideSystemLabels()
	}

	private func hideSystemLabels() {
		titleLabel?.isHidden = true
		textLabel?.isHidden = true
	}
}
