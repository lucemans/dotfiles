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
              implicitWidth: priceLabel.implicitWidth + 20
              implicitHeight: priceLabel.implicitHeight
              Layout.minimumWidth: implicitWidth
              Layout.preferredWidth: implicitWidth
              Layout.fillWidth: false

              PlasmaComponents.Label {
                  id: priceLabel
                  anchors.fill: parent
                  text: root.priceText
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
              }
          }

          property string priceText: "ETH ..."

          function refreshPrice() {
              const request = new XMLHttpRequest()

              request.onreadystatechange = function() {
                  if (request.readyState !== XMLHttpRequest.DONE) {
                      return
                  }

                  if (request.status !== 200 || request.responseText.trim() === "") {
                      root.priceText = "ETH n/a"
                      return
                  }

                  try {
                      const response = JSON.parse(request.responseText)
                      const price = Number(response.ethereum && response.ethereum.usd)

                      root.priceText = Number.isFinite(price) && price > 0
                          ? "ETH $" + price.toLocaleString(Qt.locale("en_US"), "f", 0)
                          : "ETH n/a"
                  } catch (error) {
                      root.priceText = "ETH n/a"
                  }
              }

              request.open("GET", "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd", true)
              request.send()
          }

          Timer {
              interval: 300000
              running: true
              repeat: true
              triggeredOnStart: true
              onTriggered: root.refreshPrice()
          }
      }
    '';
  in {
    packages.ethereum-price-plasmoid = pkgs.runCommand "plasma-applet-ethereum-price-1.0" {} ''
      install -Dm644 ${metadata} $out/share/plasma/plasmoids/nl.lucemans.ethereum-price/metadata.json
      install -Dm644 ${mainQml} $out/share/plasma/plasmoids/nl.lucemans.ethereum-price/contents/ui/main.qml
    '';
  };
}
