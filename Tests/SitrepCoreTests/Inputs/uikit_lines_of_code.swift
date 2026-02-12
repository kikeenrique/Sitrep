import UIKit

class BaseViewController: UIViewController {
    let name: String = ""
}

class FeatureViewController: BaseViewController {
    let subname: String = ""
}

extension BaseViewController {
    func base() {
        print("BaseViewController")
    }
}

extension FeatureViewController {
    func feature() {
        print("FeatureViewController")
    }
}

class BaseView: UIView {
    let name: String = ""
}

class FeatureView: BaseView {
    let subname: String = ""
}

extension BaseView {
    func base() {
        print("BaseViewController")
    }
}

extension FeatureView {
    func feature() {
        print("FeatureViewController")
    }
}

struct ViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}

extension ViewControllerRepresentable {
    func representable() {
        print("ViewControllerRepresentable")
    }
}

struct ViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        return UIView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
    }
}

extension ViewRepresentable {
    func representable() {
        print("ViewRepresentable")
    }
}

extension UIViewController {
    func example() {
        print("Example")
    }
}

extension UIView {
    func example() {
        print("Example")
    }
}
