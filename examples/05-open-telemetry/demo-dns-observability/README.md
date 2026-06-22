# Demo

After deployment of the Almalinux container, it should produce several
DNS requests. The reason why a non-FQDN domain doesn't lead to a lot
of DNS calls in my specific case was, that both Python and (the
current implementation of) go have libraries that add search paths
to the URL when no dots are present. The first search path to add
is `05-opentelemetry.svc.cluster.local`, which is the correct one for
my service.

I asked Kiro to change the script a bit to do add different paths.
This is the result:

![Result](./2nd%20tile%20of%20dashboard.png)
