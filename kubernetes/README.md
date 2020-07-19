# Kubernetes usage of "headless" VNC Docker images

* statefulset-with-ingress
  * use statefulset and ingress
  * no volume
* statefulset-with-ingress-and-volume
  * persistent /root dir
* statefulset-with-ingress-and-volume-full
  * persistent "/root" "/usr" "/etc" "/var" "/run" "/home" "/opt" "/srv" "/headless"

