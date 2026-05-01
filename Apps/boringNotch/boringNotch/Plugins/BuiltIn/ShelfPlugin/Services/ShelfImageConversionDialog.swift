//
//  ShelfImageConversionDialog.swift
//  boringNotch
//
//  Extracted from ShelfActionService.swift — image conversion dialog builder.
//

import AppKit
import Foundation

extension ShelfMenuActionTarget {

    // MARK: - Convert Image Dialog

    @MainActor
    func showConvertImageDialog() {
        let selected = service.selection.selectedItems(in: service.items)
        let imageURLs = selected.compactMap { $0.fileURL }.filter { service.imageProcessor.isImageFile($0) }

        guard let imageURL = imageURLs.first else { return }
        guard let item = selected.first(where: { $0.fileURL == imageURL }) else { return }

        let alert = NSAlert()
        alert.messageText = "Convert Image"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Convert")
        alert.addButton(withTitle: "Cancel")

        let (accessoryView, formatPopup, imageSizePopup, customSizeField, metadataCheckbox, qualitySlider) = buildConvertImageAccessoryView()
        alert.accessoryView = accessoryView

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let format = imageFormatFromIndex(formatPopup.indexOfSelectedItem)
            let quality = qualitySlider.doubleValue
            let maxDimension = maxDimensionFromIndex(imageSizePopup.indexOfSelectedItem, customField: customSizeField)
            let removeMetadata = metadataCheckbox.state == .off

            let options = ImageConversionOptions(
                format: format,
                compressionQuality: quality,
                maxDimension: maxDimension,
                removeMetadata: removeMetadata
            )

            service.imageProcessor.convertImage(item: item, options: options, service: service) { error in
                if let error = error {
                    print("Image Conversion Failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Accessory View Builder

    private func buildConvertImageAccessoryView() -> (NSView, NSPopUpButton, NSPopUpButton, NSTextField, NSButton, NSSlider) {
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 180))
        accessoryView.wantsLayer = true

        let formatLabel = NSTextField(labelWithString: "Format:")
        formatLabel.frame = NSRect(x: 0, y: 145, width: 100, height: 20)
        formatLabel.font = .systemFont(ofSize: 12, weight: .medium)
        accessoryView.addSubview(formatLabel)

        let formatPopup = NSPopUpButton(frame: NSRect(x: 120, y: 140, width: 250, height: 28))
        formatPopup.addItems(withTitles: ["PNG", "JPEG", "HEIC", "TIFF", "BMP"])
        formatPopup.selectItem(at: 0)
        formatPopup.font = .systemFont(ofSize: 12)
        accessoryView.addSubview(formatPopup)

        let imageSizeLabel = NSTextField(labelWithString: "Image Size:")
        imageSizeLabel.frame = NSRect(x: 0, y: 105, width: 100, height: 20)
        imageSizeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        accessoryView.addSubview(imageSizeLabel)

        let imageSizePopup = NSPopUpButton(frame: NSRect(x: 120, y: 100, width: 160, height: 28))
        imageSizePopup.addItems(withTitles: ["Actual Size", "Large", "Medium", "Small", "Custom..."])
        imageSizePopup.selectItem(at: 0)
        imageSizePopup.font = .systemFont(ofSize: 12)
        accessoryView.addSubview(imageSizePopup)

        let customSizeField = NSTextField(frame: NSRect(x: 285, y: 103, width: 85, height: 22))
        customSizeField.placeholderString = "e.g., 1920"
        customSizeField.font = .systemFont(ofSize: 12)
        customSizeField.isHidden = true
        accessoryView.addSubview(customSizeField)

        let metadataCheckbox = NSButton(checkboxWithTitle: "Preserve Metadata", target: nil, action: nil)
        metadataCheckbox.frame = NSRect(x: 120, y: 65, width: 200, height: 20)
        metadataCheckbox.font = .systemFont(ofSize: 12)
        metadataCheckbox.state = .on
        accessoryView.addSubview(metadataCheckbox)

        let separatorLine = NSView(frame: NSRect(x: 0, y: 50, width: 380, height: 1))
        separatorLine.wantsLayer = true
        separatorLine.layer?.backgroundColor = NSColor.separatorColor.cgColor
        accessoryView.addSubview(separatorLine)

        let qualityLabel = NSTextField(labelWithString: "Compression:")
        qualityLabel.frame = NSRect(x: 0, y: 22, width: 100, height: 20)
        qualityLabel.font = .systemFont(ofSize: 12, weight: .medium)
        accessoryView.addSubview(qualityLabel)

        let qualitySlider = NSSlider(frame: NSRect(x: 120, y: 22, width: 200, height: 20))
        qualitySlider.minValue = 0.0
        qualitySlider.maxValue = 1.0
        qualitySlider.doubleValue = 0.85
        accessoryView.addSubview(qualitySlider)

        let qualityValueLabel = NSTextField(labelWithString: "85%")
        qualityValueLabel.frame = NSRect(x: 325, y: 22, width: 55, height: 20)
        qualityValueLabel.font = .systemFont(ofSize: 12)
        qualityValueLabel.alignment = .left
        accessoryView.addSubview(qualityValueLabel)

        let handler = ConvertDialogHandler(
            formatPopup: formatPopup,
            qualitySlider: qualitySlider,
            qualityValueLabel: qualityValueLabel,
            qualityLabel: qualityLabel,
            imageSizePopup: imageSizePopup,
            customSizeField: customSizeField
        )
        qualitySlider.target = handler
        qualitySlider.action = #selector(ConvertDialogHandler.sliderChanged(_:))
        qualitySlider.isContinuous = true
        formatPopup.target = handler
        formatPopup.action = #selector(ConvertDialogHandler.formatChanged(_:))
        imageSizePopup.target = handler
        imageSizePopup.action = #selector(ConvertDialogHandler.sizeChanged(_:))

        handler.updateAll()
        ShelfMenuActionTarget.sliderHandlerAssoc[accessoryView] = handler

        return (accessoryView, formatPopup, imageSizePopup, customSizeField, metadataCheckbox, qualitySlider)
    }

    // MARK: - Conversion Helpers

    private func imageFormatFromIndex(_ index: Int) -> ImageConversionOptions.ImageFormat {
        switch index {
        case 0: return .png
        case 1: return .jpeg
        case 2: return .heic
        case 3: return .tiff
        case 4: return .bmp
        default: return .png
        }
    }

    private func maxDimensionFromIndex(_ index: Int, customField: NSTextField) -> CGFloat? {
        switch index {
        case 0: return nil
        case 1: return 1280
        case 2: return 640
        case 3: return 320
        case 4:
            let text = customField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, let value = Double(text), value > 0 else { return nil }
            return CGFloat(value)
        default: return nil
        }
    }
}

// MARK: - ConvertDialogHandler

class ConvertDialogHandler: NSObject {
    weak var formatPopup: NSPopUpButton?
    weak var qualitySlider: NSSlider?
    weak var qualityValueLabel: NSTextField?
    weak var qualityLabel: NSTextField?
    weak var imageSizePopup: NSPopUpButton?
    weak var customSizeField: NSTextField?

    init(formatPopup: NSPopUpButton, qualitySlider: NSSlider, qualityValueLabel: NSTextField, qualityLabel: NSTextField, imageSizePopup: NSPopUpButton, customSizeField: NSTextField) {
        self.formatPopup = formatPopup
        self.qualitySlider = qualitySlider
        self.qualityValueLabel = qualityValueLabel
        self.qualityLabel = qualityLabel
        self.imageSizePopup = imageSizePopup
        self.customSizeField = customSizeField
    }

    func updateAll() {
        updateQualityLabel()
        updateCompressionVisibility()
        updateCustomSizeVisibility()
    }

    @objc func sliderChanged(_ sender: NSSlider) { updateQualityLabel() }
    @objc func formatChanged(_ sender: NSPopUpButton) { updateCompressionVisibility() }
    @objc func sizeChanged(_ sender: NSPopUpButton) { updateCustomSizeVisibility() }

    private func updateQualityLabel() {
        guard let slider = qualitySlider else { return }
        qualityValueLabel?.stringValue = "\(Int(slider.doubleValue * 100))%"
    }

    private func updateCompressionVisibility() {
        guard let formatIndex = formatPopup?.indexOfSelectedItem else { return }
        let show = formatIndex == 1 || formatIndex == 2
        qualitySlider?.isHidden = !show
        qualityValueLabel?.isHidden = !show
        qualityLabel?.isHidden = !show
    }

    private func updateCustomSizeVisibility() {
        guard let sizeIndex = imageSizePopup?.indexOfSelectedItem else { return }
        customSizeField?.isHidden = sizeIndex != 4
    }
}
