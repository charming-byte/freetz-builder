# freetz-builder

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](https://opensource.org/licenses/MIT)
![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/charming-byte/freetz-builder/build.yml?style=flat-square&label=Build%20Status)

Automated builder for Freetz-NG. I use this setup to automate custom firmware builds for freetz-ng.
This repo checks upstream changes, applies local configs, builds the firmware, renames artifacts with commit metadata, and notifies about build state updates either per telegram, mattermost or discord.

## Table of Contents

- [🚀 How to Use](#-how-to-use)
  - [🛠️ Setup](#️-setup)
  - [⚙️ Running Builds](#️-running-builds)
  - [🔄 Customization](#-customization)
  - [📦 Accessing Build Artifacts](#-accessing-build-artifacts)
- [💻 Technologies and Tools](#-technologies-and-tools)
- [📄 License](#-license)

## 🚀 How to Use

### 🛠️ Setup

1. **Fork or clone this repository** to your own GitHub account.

2. **Configure GitHub Secrets** for notifications (optional):
   - `TELEGRAM_TOKEN` and `TELEGRAM_CHAT_ID`: For Telegram notifications
   - `DISCORD_WEBHOOK`: For Discord notifications
   - `MATTERMOST_WEBHOOK`: For Mattermost notifications

3. **Configure Workflow permissions**
    - Ensure that your Workflow permissions are set to `Read and write permissions`

3. **Add your custom configurations**:
   - Place your Freetz-NG `.config` file in the [`configs/`](./configs/) directory named as `my-box.config`

### ⚙️ Running Builds

The build process can be triggered in two ways:

1. **Scheduled Builds**: The workflow runs automatically at 2:00 AM UTC daily, checking for upstream changes and building if necessary.

2. **Manual Builds**: You can trigger a build manually through the GitHub Actions interface using the "workflow_dispatch" event.

### 🔄 Customization

1. **Modify build parameters** in the `build.sh` script to adjust how the firmware is built.

2. **Self-hosted runners**: The workflow is configured to run on self-hosted runners. Make sure your runner has sufficient resources for building firmware images.

### 📦 Accessing Build Artifacts

After a successful build:

1. Navigate to the Actions tab in your GitHub repository
2. Select the completed workflow run
3. Download the firmware artifact which contains the `.image` files

The firmware files are automatically named with commit metadata, making them easy to identify and trace back to specific builds.

## 💻 Technologies and Tools

* [Freetz-NG](https://github.com/Freetz-NG/freetz-ng): Framework for building custom firmware images for AVM FRITZ!Box devices.
* [GitHub Actions](https://github.com/features/actions): Automates the pull, build, and push steps via CI.
* Webhook Notifications: Optional real-time notifications integrated using POST hooks to services like:
  * [Telegram Bot API](https://core.telegram.org/bots/api)
  * [Discord Webhooks](https://discord.com/developers/docs/resources/webhook)
  * [Mattermost Incoming Webhooks](https://developers.mattermost.com/integrate/webhooks/incoming/)

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for more details.
