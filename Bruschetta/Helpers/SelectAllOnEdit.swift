import UIKit

/// App-wide: selects the existing text whenever a text field or text view begins
/// editing, so typing overwrites the current value.
enum SelectAllOnEdit {
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        let center = NotificationCenter.default
        center.addObserver(forName: UITextField.textDidBeginEditingNotification, object: nil, queue: .main) { note in
            guard let field = note.object as? UITextField else { return }
            addKeyboardAccessory(to: field)
            DispatchQueue.main.async { field.selectAll(nil) }
        }
        center.addObserver(forName: UITextView.textDidBeginEditingNotification, object: nil, queue: .main) { note in
            guard let view = note.object as? UITextView else { return }
            addKeyboardAccessory(to: view)
            DispatchQueue.main.async { view.selectAll(nil) }
        }
    }

    /// Gives any field without its own accessory the minimize-keyboard button.
    private static func addKeyboardAccessory(to field: UITextField) {
        guard field.inputAccessoryView == nil else { return }
        field.addDoneAccessory()
        field.reloadInputViews()
    }

    private static func addKeyboardAccessory(to view: UITextView) {
        guard view.inputAccessoryView == nil else { return }
        view.inputAccessoryView = UIResponder.makeKeyboardAccessory { [weak view] in
            view?.resignFirstResponder()
        }
        view.reloadInputViews()
    }
}
