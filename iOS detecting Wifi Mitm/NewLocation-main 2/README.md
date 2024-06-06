# SwiftUI: How to request location permission





In a lot of situations (not only accessing maps) we need the user to grant access to location services. This need arises from the fact that user location is private data and we need, for legal reasons, consent from the user.

Remeber that first thing we need to do is to add the permission in the info.plist file. So select your target , select the info Tab, and add the key "Privacy - Location When in Use Usage Description", for the value jot down any text explaining the reason, for example, "Please give location permission". 


![Location info.plist](https://static.wixstatic.com/media/198d86_3026026f24624762aad896388f72cc92~mv2.png)


With the new Observation framework the code is simpler and cleaner:

```
import SwiftUI
import CoreLocation

struct ContentView: View {
    @State var newlocationManager = NewLocationManager()
   
    
    var body: some View {
        VStack {
            Image(systemName: "location")
                .resizable()
                .scaledToFit()
                .frame(width: 150)
                .padding()
            
            Text("New location manager: \(newlocationManager.location?.description ?? "No Location Provided!")")
        }
        .padding()
       
        .task {
            try? await newlocationManager.requestUserAuthorization()
            try? await newlocationManager.startCurrentLocationUpdates()
            // remember that nothing will run here until the for try await loop finishes
        }
    }
}


@Observable
class NewLocationManager {
    var location: CLLocation? = nil
    
    private let locationManager = CLLocationManager()
    
    func requestUserAuthorization() async throws {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startCurrentLocationUpdates() async throws {
        for try await locationUpdate in CLLocationUpdate.liveUpdates() {
            guard let location = locationUpdate.location else { return }

            self.location = location
        }
    }
}
```





This code is an adaption of the article:
[article](https://holyswift.app/the-new-way-to-get-current-user-location-in-swiftu-tutorial/)

I don't know the person behind this [https://holyswift.app](https://holyswift.app) website, but in my opinion   is one the best Swift resources about Swift.
