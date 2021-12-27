//
//  PrimerCVVFieldView.swift
//  PrimerSDK
//
//  Created by Evangelos Pittas on 5/7/21.
//

#if canImport(UIKit)

import UIKit

public final class PrimerCVVFieldView: PrimerTextFieldView {
    
    internal var cvv: String {
        return textField._text ?? ""
    }
    public var cardNetwork: CardNetwork = .unknown
    
    override func xibSetup() {
        super.xibSetup()
        
        textField.keyboardType = .numberPad
        textField.isAccessibilityElement = true
        textField.accessibilityIdentifier = "cvc_txt_fld"
        textField.delegate = self
        isValid = { [weak self] text in
            guard let strongSelf = self else { return false }
            return text.isTypingValidCVV(cardNetwork: strongSelf.cardNetwork)
        }
    }
    
    public override func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let primerTextField = textField as? PrimerTextField else { return true }
        let currentText = primerTextField._text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: string) as String
        if !(newText.isNumeric || newText.isEmpty) { return false }
        if string != "" && newText.withoutWhiteSpace.count >= 5 { return false }
        
        switch self.isValid?(newText) {
        case true:
            validation = .valid
        case false:
            validation = .invalid(PrimerError.invalidCVV)
        default:
            validation = .notAvailable
        }
        
        primerTextField._text = newText
        primerTextField.text = newText
        
        switch validation {
        case .valid:
            delegate?.primerTextFieldView(self, isValid: true)
        case .invalid:
            if let cvvLength = cardNetwork.validation?.code.length, newText.count == cvvLength {
                delegate?.primerTextFieldView(self, isValid: false)
            } else {
                delegate?.primerTextFieldView(self, isValid: nil)
            }
        default:
            delegate?.primerTextFieldView(self, isValid: nil)
        }
        
        return false
    }
    
}

#endif
