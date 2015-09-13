# vaavud-ios-sdk

## Usage

In order to correctly compile:

1. Drag the `VaavudSDK.xcodeproj` into your project  
2. Go to your target's settings, hit the "+" under the "Embedded Binaries" section, and select the VaavudSDK.framework  
3. **Temporary workaround**: Xcode 6.3.1 has a bug, where you have to build your project once before actually writing the `@import` line. So hit "Build" now!  
4. `@import VaavudSDK`  
5.  When using Swift in an ObjC project:
   - You need to import your Bridging Header. Usually it is "*YourProject-Swift.h*"
   - Under "Build Options", mark "Embedded Content Contains Swift Code"

Cheers! :)
