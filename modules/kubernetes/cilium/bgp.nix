{ ... }:
{
  den.aspects.cilium-bgp = {
    k8s-manifests =
      {
        cluster,
        k3s-nodes,
        lib,
        ...
      }:
      {
        applications.cilium = {
          namespace = "kube-system";

          objects =
            let
              bgpPeers = cluster.bgp.peers;
            in
            # CiliumBGPAdvertisement: advertise LoadBalancer IPs to the router
            [
              {
                apiVersion = "cilium.io/v2alpha1";
                kind = "CiliumBGPAdvertisement";
                metadata = {
                  name = "lb-advertisement";
                  labels.advertise = "lb-ips";
                };
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
              }
              # CiliumBGPPeerConfig: shared peer config for the upstream router
              {
                apiVersion = "cilium.io/v2alpha1";
                kind = "CiliumBGPPeerConfig";
                metadata.name = "router-peer";
                spec = {
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
              }
              # CiliumLoadBalancerIPPool: LB IP range for Services
              {
                apiVersion = "cilium.io/v2alpha1";
                kind = "CiliumLoadBalancerIPPool";
                metadata.name = "lb-pool";
                spec.blocks = [
                  { cidr = cluster.networks.loadbalancers.cidr; }
                ];
              }
            ]
            # One CiliumBGPClusterConfig per k3s node (driven by k3s-nodes quirk)
            ++ map (node: {
              apiVersion = "cilium.io/v2alpha1";
              kind = "CiliumBGPClusterConfig";
              metadata.name = "cilium-bgp-${node.hostname}";
              spec = {
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
                    }) bgpPeers;
                  }
                ];
              };
            }) k3s-nodes;
        };
      };
  };
}
