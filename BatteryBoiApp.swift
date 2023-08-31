//
//  BatteryBoiApp.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 8/4/23.
//

import SwiftUI
import EnalogSwift
import Sparkle
import Combine

enum SystemDeviceTypes:String,Codable {
    case macbook
    case macbookPro
    case macbookAir
    case imac
    case macMini
    case macPro
    case macStudio
    case unknown
    
    var name:String {
        switch self {
            case .macbook: return "Macbook"
            case .macbookPro: return "Macbook Pro"
            case .macbookAir: return "Macbook Air"
            case .imac: return "iMac"
            case .macMini: return "Mac Mini"
            case .macPro: return "Mac Pro"
            case .macStudio: return "Mac Pro"
            case .unknown: return "Unknown"
            
        }
        
    }
    
    var battery:Bool {
        switch self {
            case .macbook: return true
            case .macbookPro: return true
            case .macbookAir: return true
            case .imac: return false
            case .macMini: return false
            case .macPro: return false
            case .macStudio: return false
            case .unknown: return false
            
        }
        
    }
    
}

enum SystemEvents:String {
    case fatalError = "fatal.error"
    case userInstalled = "user.installed"
    case userClicked = "user.cta"
    case userPreferences = "user.preferences"
    case userLaunched = "user.launched"

}

enum SystemDefaultsKeys: String {
    case enabledAnalytics = "sd_settings_analytics"
    case enabledLogin = "sd_settings_login"
    case enabledEstimate = "sd_settings_estimate"
    case enabledBluetooth = "sd_bluetooth_state"
    case enabledDisplay = "sd_settings_display"
    case enabledStyle = "sd_settings_style"
    case enabledTheme = "sd_settings_theme"
    
    case batteryUntilFull = "sd_charge_full"
    case batteryLastCharged = "sd_charge_last"
    case batteryDepletionRate = "sd_depletion_rate"

    case versionInstalled = "sd_version_installed"
    case versionCurrent = "sd_version_current"
    case versionIdenfiyer = "sd_version_id"

    var name:String {
        switch self {
            case .enabledAnalytics:return "Analytics"
            case .enabledLogin:return "Launch at Login"
            case .enabledEstimate:return "Battery Time Estimate"
            case .enabledBluetooth:return "Bluetooth"
            case .enabledStyle:return "Icon Style"
            case .enabledDisplay:return "Icon Display Text"
            case .enabledTheme:return "Theme"
            
            case .batteryUntilFull:return "Seconds until Charged"
            case .batteryLastCharged:return "Seconds until Charged"
            case .batteryDepletionRate:return "Battery Depletion Rate"
            
            case .versionInstalled:return "Installed on"
            case .versionCurrent:return "Active Version"
            case .versionIdenfiyer:return "App ID"

        }
        
    }
    
}

@main
struct BatteryBoiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            EmptyView()

        }
        .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        
    }
    
}

class CustomView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Draw or add your custom elements here
        
    }
    
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, ObservableObject {
    static var shared = AppDelegate()
    
    public var status:NSStatusItem? = nil
    public var hosting:NSHostingView = NSHostingView(rootView: MenuContainer())
    public var updates = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        self.status = NSStatusBar.system.statusItem(withLength: 45)
        self.hosting.frame.size = NSSize(width: 45, height: 22)
        
        if let window = NSApplication.shared.windows.first {
            window.close()

        }
        
        if let channel = Bundle.main.infoDictionary?["SD_SLACK_CHANNEL"] as? String  {
            EnalogManager.main.user(AppManager.shared.appIdentifyer)
            EnalogManager.main.crash(SystemEvents.fatalError, channel: .init(.slack, id:channel))
            EnalogManager.main.ingest(SystemEvents.userLaunched, description: "Launched BatteryBoi")

        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            _ = SettingsManager.shared.enabledTheme
            _ = SettingsManager.shared.enabledDisplay()
            
            print("\n\nApp Version: \(AppManager.shared.appInstalled)\n\n")
            
            UpdateManager.shared.updateCheck()
            
            switch BatteryManager.shared.charging.state {
                case .battery : WindowManager.shared.windowOpen(.userLaunched, device: nil)
                case .charging : WindowManager.shared.windowOpen(.chargingBegan, device: nil)
                
            }
            
            SettingsManager.shared.$display.sink { type in
                switch type {
                    case .hidden : self.applicationMenuBarIcon(false)
                    default : self.applicationMenuBarIcon(true)
                    
                }
                
            }.store(in: &self.updates)
            
            if #available(macOS 13.0, *) {
                if SettingsManager.shared.enabledAutoLaunch == .undetermined {
                    SettingsManager.shared.enabledAutoLaunch = .enabled
                    
                }
                
            }
            
        }
        
    }
    
    private func applicationMenuBarIcon(_ visible:Bool) {
        if visible == true {
            if let button = self.status?.button {
                button.title = ""
                button.addSubview(self.hosting)
                button.action = #selector(applicationStatusBarButtonClicked(sender:))
                button.target = self
                
            }
            
        }
        else {
            if let button = self.status?.button {
                button.subviews.forEach { $0.removeFromSuperview() }
                
            }
            
        }
        
    }
    
    @objc func applicationStatusBarButtonClicked(sender: NSStatusBarButton) {
        #if DEBUG
            WindowManager.shared.windowOpen(.chargingBegan, device: nil)

        #else
            WindowManager.shared.windowOpen(.userInitiated, device: nil)

        #endif
                
    }
    
    @objc func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.windowOpen(.userInitiated, device: nil)

        return false
        
    }

}
