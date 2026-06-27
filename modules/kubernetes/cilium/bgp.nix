{ ... }:
{
  den.aspects.cilium-bgp = {
    k8s-manifests =
      {
        generators,
        charts,
        config,
        lib,
        k3s-nodes,
        ...
      }:
      {
        # Register Cilium BGP CRD types for typed resource declarations below.
        nixidy.applicationImports = [
          (generators.fromChartCRDModule {
            name = "cilium-bgp";
            chart = charts.cilium.cilium;
            kindFilter = [
              "CiliumBGPAdvertisement"
              "CiliumBGPPeerConfig"
              "CiliumBGPClusterConfig"
              "CiliumLoadBalancerIPPool"
            ];
          })
        ];

        applications.cilium = {
          namespace = "kube-system";

          resources = {
            # Advertise LoadBalancer IPs to the router
            ciliumBGPAdvertisements.lb-advertisement = {
              metadata.labels.advertise = "lb-ips";
              spec.advertisements = [
                {
                  advertisementType = "Service";
                  service.addresses = [
                    "ExternalIP"
                    "LoadBalancerIP"
                  ];
                  selector.matchExpressions = [
                    {
                      key = "service.kubernetes.io/headless";
                      operator = "DoesNotExist";
                    }
                  ];
                }
              ];
            };

            # Shared peer config for the upstream router
            ciliumBGPPeerConfigs.router-peer.spec = {
              ebgpMultihop = 1;
              timers = {
                connectRetryTimeSeconds = 5;
                holdTimeSeconds = 30;
                keepAliveTimeSeconds = 10;
              };
              gracefulRestart = {
                enabled = true;
                restartTimeSeconds = 15;
              };
              families = [
                {
                  afi = "ipv4";
                  safi = "unicast";
                  advertisements.matchLabels.advertise = "lb-ips";
                }
              ];
            };

            # One CiliumBGPClusterConfig per node, driven by the k3s-nodes quirk.
            # Den threads k3s-nodes as a module arg via the cluster-collect-k3s-nodes
            # pipe and cluster-to-nixidy instantiate policy.
            ciliumBGPClusterConfigs = lib.listToAttrs (
              map (node: {
                name = "cilium-bgp-${node.hostname}";
                value.spec = {
                  nodeSelector.matchLabels."kubernetes.io/hostname" = node.hostname;
                  bgpInstances = [
                    {
                      name = "router-session";
                      localASN = node.localASN;
                      peers = map (peer: {
                        name = peer.name;
                        peerASN = peer.asn;
                        peerAddress = peer.ip;
                        peerConfigRef.name = "router-peer";
                      }) config.cluster.bgp.peers;
                    }
                  ];
                };
              }) k3s-nodes
            );

            # LB IP pool — Cilium allocates IPs from this range for LoadBalancer Services
            ciliumLoadBalancerIPPools."lb-pool".spec.blocks = [
              { cidr = config.cluster.networks.lbCIDR; }
            ];
          };
        };
      };
  };
}
