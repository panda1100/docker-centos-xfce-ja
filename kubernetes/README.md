# Kubernetes manifests directories

* statefulset-with-lb dir
  * use statefulset and Service(LoadBalancer)
  * terminalte ssl at container
* statefulset-with-ingress dir
  * use statefulset and ingress
  * terminalte ssl at ingress
  * no volume
* statefulset-with-ingress-and-volume dir
  * persistent /root dir using pvc
  * terminalte ssl at ingress
* statefulset-with-ingress-and-volume-full dir
  * persistent "/root" "/usr" "/etc" "/var" "/run" "/home" "/opt" "/srv" "/headless" using pvc
  * terminalte ssl at ingress
