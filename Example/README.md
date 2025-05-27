# Example App

This example demonstrates how to use the LocalLLMClient to integrate on-device LLMs into an iOS / macOS app.

<table>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/f949ba1d-f063-463c-a6fa-dcdf14c01e8b" width="100%" alt="example on iOS" /></td>
    <td><img src="https://github.com/user-attachments/assets/3ac6aef5-df1a-45e9-8989-e4dbce223ceb" width="100%" alt="example on macOS" /></td>
  </tr>
</table>

## Requirements

- iOS 18.0+ / macOS 15.0+
- Xcode 16.3+
- [Recommended]: M1 Mac or newer, or recent iPhone Pro models

## Usage

To run the example app:

1. Clone the repository:
  ```bash
  git clone --recursive https://github.com/tattn/LocalLLMClient
  ```
  If you already cloned the repository without `--recursive`, run:
  ```bash
  git submodule update --init --recursive
  ```
2. Open `LocalLLMClientExample.xcodeproj` in Xcode
3. Build and run the app on your device, not a simulator

*Note: The app requires a physical device*

