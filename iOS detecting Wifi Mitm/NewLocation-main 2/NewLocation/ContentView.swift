import SwiftUI
import Foundation
import SystemConfiguration.CaptiveNetwork
import NetworkExtension
import CoreLocation
import Network
import WebKit
import SwiftSoup

import Foundation

class TimerManager {
    private var timer: Timer?
    public var count = 0
    private var callback: ((Int) -> Void)?
    
    func startTimer(withInterval interval: TimeInterval, callback: @escaping (Int) -> Void) {
        self.callback = callback
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func fireTimer() {
        count += 1
        callback?(count)
    }
}

struct ToastView<Content: View>: View {
    let content: Content
    let duration: TimeInterval
    
    @Binding var isPresented: Bool
    
    var body: some View {
        content
            .padding()
            .background(Color.black.opacity(0.7))
            .foregroundColor(.white)
            .cornerRadius(10)
            .opacity(isPresented ? 1 : 0)
            .animation(.easeInOut(duration: 0.3))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
    }
}

struct ResultRow: View {
    let title: String
    let content: String

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 150, alignment: .leading) // align left
                .padding(.leading, 32)
                .padding(.top, 4)
            Text(content)
                .multilineTextAlignment(.leading) // align left
            Spacer()
        }
    }
}

struct NewPage: View {
    var wifiSsid: String
    var wifiBssid: String
    var ipAddress: String
    var downloadSpeed: String
    var uploadSpeed: String
    var delay: String
    var isTesting: Bool
    var body: some View {
        if wifiSsid != "" || wifiBssid != "" || ipAddress != "" || downloadSpeed != "" || uploadSpeed != "" || delay != "" {
            Text("Detect Result ")
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.title)
                .padding(.bottom, 20)
                .padding(.top, 20)
                .padding(.leading, 32)
        }
        if wifiSsid != "" {
            ResultRow(title: "SSID:", content: wifiSsid)
        }
        if wifiBssid != "" {
            ResultRow(title: "MAC Address：", content: wifiBssid) // wifi mac, not machine mac
        }
        if ipAddress != "" {
            ResultRow(title: "IP Address:", content: ipAddress)
        }
        
        if downloadSpeed != "" {
            if let number = Double(downloadSpeed) {
                let str = (isTesting && number == 0) ? "Loading..." : "\(number / 8) Mb/s"
                ResultRow(title: "Download Speed:", content: str)
            }  else {
                let str = downloadSpeed == "..." ? "Loading..." : downloadSpeed
                ResultRow(title: "Download Speed:", content: str)
            }
        }
        if uploadSpeed != "" {
            if let number = Double(uploadSpeed) {
                let str = isTesting && number == 0 ? "Loading..." : "\(number / 8) Mb/s"
                ResultRow(title: "Upload Speed:", content: str)
            }  else {
                let str = uploadSpeed == "..." ? "Loading..." : uploadSpeed
                ResultRow(title: "Upload Speed:", content: str)
            }
        }
        if delay != "" {
            if let number = Double(uploadSpeed) {
                let str = isTesting && number == 0 ? "Loading..." : (delay  + "ms")
                ResultRow(title: "Network Delay:", content: str)
            }  else {
                let str = delay == "..." ? "Loading..." : delay
                ResultRow(title: "Network Delay:", content: str)
            }
        }
        
        Spacer()

    }
}

struct WebViewWrapper: UIViewRepresentable {
    @Binding var webView: WKWebView
    var onPageFinished: (() -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Update the webview if needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, onPageFinished: onPageFinished)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewWrapper
        var onPageFinished: (() -> Void)?
        
        init(_ parent: WebViewWrapper, onPageFinished: (() -> Void)?) {
            self.parent = parent
            self.onPageFinished = onPageFinished
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Call the callback function when the webview finishes loading
            onPageFinished?()
        }
    }
    
    func loadUrl(_ urlString: String) {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    func callJavaScriptFunction(_ script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        webView.evaluateJavaScript(script, completionHandler: completion)
    }
}

struct ContentView: View {
//    @State var newlocationManager = NewLocationManager()
    private let locationManager = CLLocationManager()
    private let timerManager = TimerManager()
    private let speedTimerManager = TimerManager()
    @State private var showToast = false
    @State private var buttonText = "start"
    @State private var errMsg = ""
    @State private var isConnectedToWiFi: Bool = false
    @State private var wifiSsid = ""
    @State private var wifiBssid = ""
    @State private var ipAddress = ""
    @State private var downloadSpeed = ""
    @State private var uploadSpeed = ""
    @State private var delay = ""
    @State private var lastSpeed = 0.0
    @State private var lastIp = ""
    @State private var webviewTesting = false
    
    @State private var parameter1: String = ""
    @State private var parameter2: Int = 0

    @State private var webView = WKWebView()


    var body: some View {
        NavigationView {
            VStack {
                
                Spacer().frame(height: 200)
                
                
                // only int network enable
                WebViewWrapper(webView: $webView, onPageFinished: {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        executeTask(count: 1)
                    }
                })
                .onAppear {
                    // loadWebPage()
                }.frame(height: 0)
                
                Button(action: {
                    if(self.buttonText == "start"){

                        self.lastSpeed = 0
                        self.lastIp = ""
                        loadWebPage()
                        startDetect()
                        self.timerManager.startTimer(withInterval: 5) { count in
                            startDetect()
                            // 处理回调的逻辑
                             print("timerManager count: \(String(describing: count))")
                        }
                        self.speedTimerManager.startTimer(withInterval: 25) { count in
                            loadWebPage()
                            // 处理回调的逻辑
                             print("speedTimerManager count: \(String(describing: count))")
                        }
                    }  else  {
                        self.timerManager.stopTimer()
                        self.speedTimerManager.stopTimer()
                        self.buttonText = "start"
                    }
                    
                }) {
                    Text(buttonText)
                        .foregroundColor(.white)
                        .frame(width: 150, height: 50)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                        .font(Font.system(size: 24))
                }
                
                if wifiSsid != "" || wifiBssid != "" || ipAddress != "" || downloadSpeed != "" || uploadSpeed != "" ||  delay != "" {
                    NavigationLink(destination: NewPage(wifiSsid: wifiSsid, wifiBssid: wifiBssid,ipAddress:ipAddress, downloadSpeed: downloadSpeed, uploadSpeed: uploadSpeed, delay: delay, isTesting: webviewTesting )) {
                       Text("result")
                           .padding()
                           .frame(width: 150, height: 50)
                           .padding()
                           .foregroundColor(.white)
                           .background(Color.blue)
                           .cornerRadius(16)
                           .font(Font.system(size: 24))
                   }
                }
                
              
                Spacer()
                
                if showToast {
                    ToastView(content: Text("\(errMsg)"), duration: 2, isPresented: $showToast)
                }
            }.task {
                await getWifi()
                locationManager.requestWhenInUseAuthorization()
                requestWiFiPermission()
                
                //            let ret1: ()? = try? await newlocationManager.requestUserAuthorization()
                //            let ret2: ()? = try? await newlocationManager.startCurrentLocationUpdates()
                // remember that nothing will run here until the for try await loop finishes
            }
        }
    }
    
    private func loadWebPage(_url: String = "https://test.ustc.edu.cn/") {
        let radom = Double.random(in: 0...1)
        let target = _url + "?r=" + String(radom)
        if let url = URL(string: target) {
            webView.load(URLRequest(url: url))
        }
    }
    
    private func callJavaScriptFunction() {
        webView.evaluateJavaScript("alert('Hello from SwiftUI!')", completionHandler: nil)
    }
    
    func executeTask(count: Int) {
        self.webviewTesting = true;
        
        if(self.buttonText != "detecting...") {
            self.webviewTesting = false;
            return
        }
        
        if count < 10 {
            print("speed Task executed, count: \(count)")
            webView.evaluateJavaScript("document.getElementById('dlText').innerHTML") { (result, error) in
                if let dlText = result as? String {
                    print("dlText: \(String(describing: dlText))")
                    if dlText != "" {
                        self.downloadSpeed = dlText
                    }
                }
            }
            webView.evaluateJavaScript("document.getElementById('ulText').innerHTML") { (result, error) in
                if let ulText = result as? String {
                    print("ulText: \(String(describing: ulText))")
                    if ulText != "" {
                        self.uploadSpeed = ulText
                    }
                }
            }
            webView.evaluateJavaScript("document.getElementById('pingText').innerHTML") { (result, error) in
                if let pingText = result as? String {
                    print("pingText: \(String(describing: pingText))")
                    if pingText != "" {
                        self.delay = pingText
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                executeTask(count: count + 1)
            }
        } else {
            self.webviewTesting = false;

            if(self.buttonText == "start") {
                return
            }
            
            if(self.downloadSpeed == "" || self.downloadSpeed == "..."){
                return
            }
            
            // check speed normal
            if let downloadSpeed = Double(self.downloadSpeed) {
                if(downloadSpeed < 0.01){
                    errMsg = "The network slowly "
                    showToast.toggle()
                } else if (downloadSpeed > 0 && self.lastSpeed > 0 && downloadSpeed / self.lastSpeed > 5){
                    errMsg = "The network speed is abnormal"
                    print("curSpeed: \(String(describing: downloadSpeed))")
                    print("lastSpeed: \(String(describing: self.lastSpeed))")
                    print("size: \(String(downloadSpeed / self.lastSpeed))")
                    showToast.toggle()
                }
                self.lastSpeed = downloadSpeed;
            }
            // let uploadSpeed = Double(self.uploadSpeed)!
           
        }
    }
    
    func getWifi() async {
        let w = await NEHotspotNetwork.fetchCurrent()
        
        print("getWifi \(String(describing: w))")
        
        guard let w else {return}
      
            wifiSsid = w.ssid
            wifiBssid = w.bssid
    }
    
    func getWIFISSID()  {
        NEHotspotNetwork.fetchCurrent(completionHandler: { (network) in
          
            if let network {
                
                print(network.description)
                let networkSSID = network.ssid
                wifiSsid = networkSSID
                wifiBssid = network.bssid
                print(networkSSID)
                print("Network: \(networkSSID) and signal strength %d",  network.signalStrength)
            } else {
                print("No available network")
//                errMsg = "fetch SSID failed"
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//                    self.buttonText = "start"
//                }
//                showToast.toggle()
//                showToast.toggle()
            }
        })
    }
    
    func pingNetorkEnable(){
        let radom = Double.random(in: 0...1)
        let url = URL(string: "https://test.ustc.edu.cn/backend/garbage.php?r=\(radom)&ckSize=0.001")!
        let startTime = Date()
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // forbid cache
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                errMsg = "The network error "
                showToast.toggle()
                print("Error: \(error)")
            } else {
                let endTime = Date()
                let elapsedTime = endTime.timeIntervalSince(startTime)
                let speed: Double = 0.001 / elapsedTime
                if(speed < 0.0003){
                    errMsg = "The network slowly "
                    showToast.toggle()
                }
                print("downloadSpeed  \(speed), elapsedTime \(elapsedTime), url:\(url), radom:\(radom)")
            }
        }.resume()
    }
    
    func testSpeed(){
        let radom = Double.random(in: 0...1)
        let url = URL(string: "https://test.ustc.edu.cn/backend/garbage.php?r=\(radom)&ckSize=0.5")!
        let startTime = Date()
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // forbid cache
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                errMsg = "The network error "
                showToast.toggle()
                print("Error: \(error)")
            } else {
                let endTime = Date()
                let elapsedTime = endTime.timeIntervalSince(startTime)
                let speed: Double = 0.5 / elapsedTime
                if(speed < 0.01){
                    errMsg = "The network slowly "
                    showToast.toggle()
                } else if (speed > 0 && speed / self.lastSpeed > 8){
                    errMsg = "The network speed is abnormal"
                    showToast.toggle()
                }
                self.lastSpeed = speed;
                self.downloadSpeed = String(format: "%.1f", speed)
                print("downloadSpeed  \(downloadSpeed), elapsedTime \(elapsedTime), url:\(url), radom:\(radom)")
            }
        }.resume()
    }
    
    
    // wan
    func  getWanIpAddress(){
        print("getIpAddress  11")
       guard let url = URL(string: "https://api.ipify.org") else {
           return
       }
       
       URLSession.shared.dataTask(with: url) { data, response, error in
           guard let data = data, error == nil else {
               return
           }
           print("getIpAddress  \(data)")

           if let ip = String(data: data, encoding: .utf8) {
               DispatchQueue.main.async {
                   self.ipAddress = ip
               }
           }
       }.resume()
    }
    
    // lan
    func getLanIpAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                let interfaceName = String(cString: (ptr?.pointee.ifa_name)!)
                if interfaceName.hasPrefix("en") { // Assuming Wi-Fi interface name starts with "en"
                    let saFamily = ptr?.pointee.ifa_addr.pointee.sa_family
                    if saFamily == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(ptr?.pointee.ifa_addr, socklen_t((ptr?.pointee.ifa_addr.pointee.sa_len)!),
                                       &hostname, socklen_t(hostname.count),
                                       nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                            address = String(cString: hostname)
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        let target = address ?? ""
        if(self.lastIp != "" && self.lastIp != target){
            errMsg = "The IP Address changed "
            showToast.toggle()
        }
        self.lastIp = target
        self.ipAddress = target
        return target
    }
    
    func checkWiFiConnection() {
        let connectivityMonitor = NWPathMonitor()

        connectivityMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnectedToWiFi = path.status == .satisfied && path.usesInterfaceType(.wifi)
                
                print("isConnectedToWiFi  \(isConnectedToWiFi)")

            }
        }

        let queue = DispatchQueue(label: "ConnectivityMonitor")
        connectivityMonitor.start(queue: queue)
    }
    
    func getWifiSSID2() -> String? {
        var ssid: String?
        
        if #available(iOS 13.0, *) {
            let interfaces = CNCopySupportedInterfaces() as? [String]
            if let interface = interfaces?.first {
                let networkInfo = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary?
                ssid = networkInfo?[kCNNetworkInfoKeySSID] as? String
            }
        } else {
            if let interfaces = CNCopySupportedInterfaces() as? [String] {
                for interface in interfaces {
                    let dict = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary?
                    ssid = dict?[kCNNetworkInfoKeySSID] as? String
                    if ssid != nil {
                        break
                    }
                }
            }
        }
        
        print("getWifiSSID2  \(String(describing: ssid))")

        
        return ssid
    }
    
    func requestWiFiPermission() {
          if #available(iOS 13.0, *) {
              NEHotspotConfigurationManager.shared.getConfiguredSSIDs { result in
                  print("requestWiFiPermission  \(String(describing: result))")
//                  switch result {
//                  case .success(let ssids):
//                      if let connectedSSID = ssids.first {
//                          self.ssids = [connectedSSID]
//                      } else {
//                          self.errorMessage = "No Wi-Fi connected"
//                      }
//                  case .failure(let error):
//                      self.errorMessage = error.localizedDescription
//                  }
              }
          } else {
              // handle < ios13
          }
      }
    
    func startDetect(){
       self.buttonText = "detecting..."
       //                checkWiFiConnection()
       //                getWifiSSID2()
       getWIFISSID()
       pingNetorkEnable()
       getLanIpAddress()
      
    }

    
}






#Preview {
    ContentView()
}
