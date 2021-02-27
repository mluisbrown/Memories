import UIKit
import Core
import ReactiveCocoa
import ReactiveSwift

enum Appearance: String {
    case dark
    case light
    case system
}

class AppearanceViewController: UITableViewController {

    @IBOutlet weak var darkCell: UITableViewCell!
    @IBOutlet weak var lightCell: UITableViewCell!
    @IBOutlet weak var systemCell: UITableViewCell!

    private var cells: [UITableViewCell: Appearance] = [:]
    private let appearanceObserver: Signal<Appearance, Never>.Observer

    private let viewModel: AppearanceViewModel

    required init?(coder aDecoder: NSCoder) {
        let selectedAppearance: Signal<Appearance, Never>
        (selectedAppearance, appearanceObserver) = Signal<Appearance, Never>.pipe()
        viewModel = AppearanceViewModel(
            updateWindowStyle: Current.updateAppearance
        )

        super.init(coder: aDecoder)

        bindViewModel(selectedAppearance: selectedAppearance)
    }

    private func bindViewModel(selectedAppearance: Signal<Appearance, Never>) {
        viewModel.appearance <~ selectedAppearance

        selectedAppearance.observeValues { appearance in
            self.updateCells(appearance: appearance)
        }
    }

    private func updateCells(appearance: Appearance) {
        cells.keys.forEach { cell in
            cell.accessoryType = .none
        }

        cells.forEach { cell, cellAppearance in
            guard cellAppearance == appearance else {
                return
            }

            cell.accessoryType = .checkmark
        }
    }

    override func viewDidLoad() {
        cells = [
            darkCell: .dark,
            lightCell: .light,
            systemCell: .system
        ]

        updateCells(appearance: viewModel.appearance.value)
    }

    // MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath),
            let appearance = cells[cell]
        else { return }

        appearanceObserver.send(value: appearance)
    }
}

struct AppearanceViewModel {
    static let appearanceKey = "appearance"
    let appearance = MutableProperty<Appearance>(.system)

    init(
        updateWindowStyle: @escaping (Appearance) -> Void
    ) {
        if let setting = Current.userDefaults.string(forKey: AppearanceViewModel.appearanceKey),
            let appearance = Appearance.init(rawValue: setting) {
            self.appearance.value = appearance
        }

        self.appearance.signal
            .observeValues { appearance in
                updateWindowStyle(appearance)
            }
    }
}
