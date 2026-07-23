{...}: {
  perSystem = {pkgs, ...}: let
    metadata = pkgs.writeText "ethereum-price-metadata.json" (builtins.toJSON {
      KPackageStructure = "Plasma/Applet";
      KPlugin = {
        Authors = [
          {
            Email = "luc@lucemans.nl";
            Name = "Luc";
          }
        ];
        Category = "Online Services";
        Description = "Shows the current Ethereum price in USD.";
        Icon = "network-connect";
        Id = "nl.lucemans.ethereum-price";
        Name = "Ethereum Price";
        Version = "1.0";
      };
      X-Plasma-API-Minimum-Version = "6.0";
    });

    mainQml = pkgs.writeText "ethereum-price-main.qml" ''
      import QtQuick
      import QtQuick.Layouts
      import org.kde.plasma.plasmoid
      import org.kde.plasma.components as PlasmaComponents

       PlasmoidItem {
           id: root

           preferredRepresentation: fullRepresentation
           fullRepresentation: Item {
               implicitWidth: content.implicitWidth + 20
               implicitHeight: content.implicitHeight + 6
               Layout.minimumWidth: implicitWidth
               Layout.preferredWidth: implicitWidth
               Layout.fillWidth: false

               ColumnLayout {
                   id: content
                   anchors.centerIn: parent
                   spacing: 0

                   PlasmaComponents.Label {
                       id: priceLabel
                       Layout.alignment: Qt.AlignHCenter
                       text: root.priceText
                       font.bold: true
                   }

                   PlasmaComponents.Label {
                       Layout.alignment: Qt.AlignHCenter
                       text: root.statusText()
                       font.pixelSize: Math.max(9, priceLabel.font.pixelSize - 2)
                       opacity: 0.7
                   }
               }

               MouseArea {
                   anchors.fill: parent
                   cursorShape: Qt.PointingHandCursor
                   onClicked: root.toggleTurboMode()
               }
           }

           property string priceText: "ETH ..."
           property bool turboMode: false
           property bool refreshInFlight: false
           property bool hasRefreshError: false
           property double lastSuccessfulRefreshMs: 0
           property double nextRefreshMs: 0
           property int clockTick: 0
           property int normalRefreshIntervalMs: 600000
           property int turboRefreshIntervalMs: 180000

           readonly property int refreshIntervalMs: turboMode
               ? turboRefreshIntervalMs
               : normalRefreshIntervalMs

           function durationText(milliseconds) {
               const seconds = Math.max(0, Math.ceil(milliseconds / 1000))

               if (seconds < 60) {
                   return seconds + "s"
               }

               const minutes = Math.floor(seconds / 60)
               const remainingSeconds = seconds % 60
               return minutes + "m " + remainingSeconds + "s"
           }

           function statusText() {
               clockTick

               if (refreshInFlight) {
                   return turboMode ? "TURBO · refreshing" : "Refreshing"
               }

               if (lastSuccessfulRefreshMs === 0) {
                   return hasRefreshError ? "Waiting to retry" : "Loading quote"
               }

               const remainingMs = nextRefreshMs - Date.now()
               const prefix = turboMode ? "TURBO · " : ""

               if (remainingMs <= 0) {
                   return prefix + "overdue · " + durationText(-remainingMs)
               }

               if (remainingMs <= Math.min(30000, refreshIntervalMs * 0.15)) {
                   return prefix + "soon · " + durationText(remainingMs)
               }

               if (hasRefreshError) {
                   return prefix + "Stale · retry in " + durationText(remainingMs)
               }

               return prefix + " " + durationText(remainingMs)
           }

           function scheduleRefresh(delayMs) {
               nextRefreshMs = Date.now() + delayMs
               refreshTimer.interval = Math.max(1, delayMs)
               refreshTimer.restart()
           }

           function toggleTurboMode() {
               turboMode = !turboMode
               refreshPrice()
           }

           function refreshPrice() {
               if (refreshInFlight) {
                   return
               }

               refreshInFlight = true
               const request = new XMLHttpRequest()

               request.onreadystatechange = function() {
                   if (request.readyState !== XMLHttpRequest.DONE) {
                       return
                   }

                   refreshInFlight = false

                   if (request.status !== 200 || request.responseText.trim() === "") {
                       hasRefreshError = true
                       scheduleRefresh(Math.min(refreshIntervalMs, 30000))
                       return
                   }

                   try {
                       const response = JSON.parse(request.responseText)
                       const price = Number(response.ethereum && response.ethereum.usd)

                       if (!Number.isFinite(price) || price <= 0) {
                           hasRefreshError = true
                           scheduleRefresh(Math.min(refreshIntervalMs, 30000))
                           return
                       }

                       root.priceText = "ETH $" + price.toLocaleString(Qt.locale("en_US"), "f", 0)
                       lastSuccessfulRefreshMs = Date.now()
                       hasRefreshError = false
                       scheduleRefresh(refreshIntervalMs)
                   } catch (error) {
                       hasRefreshError = true
                       scheduleRefresh(Math.min(refreshIntervalMs, 30000))
                   }
               }

              request.open("GET", "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd", true)
              request.send()
          }

           Timer {
               id: refreshTimer
               interval: root.normalRefreshIntervalMs
               running: true
               repeat: false
               onTriggered: root.refreshPrice()
           }

           Timer {
               interval: 1000
               running: true
               repeat: true
               triggeredOnStart: true
               onTriggered: root.clockTick += 1
           }

           Component.onCompleted: refreshPrice()
       }
    '';
  in {
    packages.ethereum-price-plasmoid = pkgs.runCommand "plasma-applet-ethereum-price-1.0" {} ''
      install -Dm644 ${metadata} $out/share/plasma/plasmoids/nl.lucemans.ethereum-price/metadata.json
      install -Dm644 ${mainQml} $out/share/plasma/plasmoids/nl.lucemans.ethereum-price/contents/ui/main.qml
    '';
  };
}
