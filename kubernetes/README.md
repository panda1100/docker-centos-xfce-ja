# Kubernetes manifests directories

* statefulset-with-ingress dir
  * use statefulset and ingress
  * no volume
* statefulset-with-ingress-and-volume dir
  * persistent /root dir using pvc
* statefulset-with-ingress-and-volume-full dir
  * persistent "/root" "/usr" "/etc" "/var" "/run" "/home" "/opt" "/srv" "/headless" using pvc

