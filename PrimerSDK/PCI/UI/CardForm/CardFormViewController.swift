import UIKit
import AuthenticationServices

class CardFormViewController: UIViewController {
    let indicator = UIActivityIndicatorView()
    private let validation = Validation()
    private let spinner = UIActivityIndicatorView()
    private let viewModel: CardFormViewModelProtocol
    private let transitionDelegate = TransitionDelegate()
    
//    var formViewTitle: String { return viewModel.uxMode == .CHECKOUT ? "Checkout" : "Add card" }
    var cardFormView: CardFormView?
    var delegate: ReloadDelegate?
    weak var router: RouterDelegate?
    
    init(with viewModel: CardFormViewModelProtocol, and router: RouterDelegate) {
        self.viewModel = viewModel
        self.router = router
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = transitionDelegate
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    public override func viewDidLoad() {
        view.backgroundColor = viewModel.theme.backgroundColor
        view.addSubview(indicator)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        indicator.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        indicator.startAnimating()
        viewModel.configureView() { [weak self] error in
            DispatchQueue.main.async {
                self?.paintView()
            }
        }
        
    }
    
    deinit { print("🧨 destroy:", self.self) }
    
    override func viewWillDisappear(_ animated: Bool) { delegate?.reload() }
    
    private func paintView() {
        cardFormView = CardFormView(frame: view.frame, theme: viewModel.theme, uxMode: viewModel.flow.uxMode, delegate: self)
        guard let cardFormView = self.cardFormView else { return print("no view") }
        view.addSubview(cardFormView)
        cardFormView.pin(to: self.view)
        addTargetsToForm()
        cardFormView.submitButton.backgroundColor = formIsNotValid ? .gray : viewModel.theme.buttonColorTheme.payButton
        hideKeyboardWhenTappedAround()
    }
    
    private func addTargetsToForm() {
        cardFormView?.cardTF.addTarget(self, action: #selector(onCardNumberTextFieldChanged), for: .editingChanged)
        cardFormView?.expTF.addTarget(self, action: #selector(onExpiryTextFieldChanged), for: .editingChanged)
        cardFormView?.submitButton.addTarget(self, action: #selector(onSubmitButtonPressed), for: .touchUpInside)
    }

    @objc private func onExpiryTextFieldChanged(_ sender: UITextField) {
        guard let currentText = sender.text else  { return }
        let dateMask = Mask(pattern: "##/##")
        sender.text = dateMask.apply(on: currentText)
    }
    
    @objc private func onCardNumberTextFieldChanged(_ sender: UITextField) {
        guard let currentText = sender.text else  { return }
        let numberMask = Mask(pattern: "#### #### #### #### ###")
        sender.text = numberMask.apply(on: currentText)
    }
    
    @objc private func onSubmitButtonPressed() {
        
        if (formIsNotValid) { return }
        
        guard let name = cardFormView?.nameTF.text else { return }
        guard var number = cardFormView?.cardTF.text else { return }
        number = number.filter { !$0.isWhitespace }
        guard let expiryValues = cardFormView?.expTF.text?.split(separator: "/") else { return }
        let expMonth = "\(expiryValues[0])"
        let expYear = "20\(expiryValues[1])"
        guard let cvc = cardFormView?.cvcTF.text else { return }
        
        self.cardFormView?.submitButton.showSpinner()
        
        let instrument = PaymentInstrument(
            number: number,
            cvv: cvc,
            expirationMonth: expMonth,
            expirationYear: expYear,
            cardholderName: name
        )
        
        viewModel.tokenize(
            instrument: instrument,
            completion: { [weak self] error in
                DispatchQueue.main.async {
                    
                    self?.view.removeFromSuperview()
                    
                    if (error != nil) {
                        self?.router?.showError()
                        return
                    }
                    
                    self?.router?.showSuccess()
                    
                }
            }
        )
    }
    
    private var formIsNotValid: Bool  {

        guard let cardFormView = self.cardFormView else { return true }
        
        let checks = [validation.nameFieldIsNotValid, validation.cardFieldIsNotValid, validation.expiryFieldIsNotValid, validation.CVCFieldIsNotValid]
        
        let fields = [cardFormView.nameTF, cardFormView.cardTF, cardFormView.expTF, cardFormView.cvcTF]
        
        var validations: [Bool] = []
        
        for (index, field) in fields.enumerated() {
            let isNotValid = checks[index](field.text)
            validations.append(isNotValid)
        }
        
        return validations.contains(true)
        
    }
}

extension CardFormViewController: CardFormViewDelegate {
    func validateCardName(_ text: String?) {
        let nameIsNotValid = validation.nameFieldIsNotValid(text)
        cardFormView?.nameTF.toggleValidity(nameIsNotValid)
        cardFormView?.submitButton.backgroundColor = formIsNotValid ? .gray : viewModel.theme.buttonColorTheme.payButton
    }
    
    func validateCardNumber(_ text: String?) {
        let cardIsNotValid = validation.cardFieldIsNotValid(text)
        cardFormView?.cardTF.toggleValidity(cardIsNotValid)
        cardFormView?.submitButton.backgroundColor = formIsNotValid ? .gray : viewModel.theme.buttonColorTheme.payButton
    }
    
    func validateExpiry(_ text: String?) {
        let expiryIsNotValid = validation.expiryFieldIsNotValid(text)
        cardFormView?.expTF.toggleValidity(expiryIsNotValid)
        cardFormView?.submitButton.backgroundColor = formIsNotValid ? .gray : viewModel.theme.buttonColorTheme.payButton
    }
    
    func validateCVC(_ text: String?) {
        let cvcIsNotValid = validation.CVCFieldIsNotValid(text)
        cardFormView?.cvcTF.toggleValidity(cvcIsNotValid)
        cardFormView?.submitButton.backgroundColor = formIsNotValid ? .gray : viewModel.theme.buttonColorTheme.payButton
    }
    
    func cancel() {
        self.view.removeFromSuperview()
        switch viewModel.flow {
        case .completeDirectCheckout: router?.showDirectCheckout()
        case .completeVaultCheckout: router?.showVaultPaymentMethods()
        default: dismiss(animated: true, completion: nil)
        }
    }
    func showScanner() {
        router?.showCardScanner(delegate: self)
    }
}
