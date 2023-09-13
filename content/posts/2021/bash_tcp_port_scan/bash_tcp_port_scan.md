---
title: Bash TCP port scan
description: Scan TCP port with pseudo-device
author: Florian
publishDate: 2021-03-20
tags:
  - 'Linux'
  - 'Bash'
---

> TL;DR
>
> With this short trick, you can check for open TCP ports on a target system, only using bash built-in features.

On Unix-like systems, there are [pseudo-devices](https://en.wikipedia.org/wiki/Device_file#Pseudo-devices) who are located at `/dev`. These are interfaces without actual hardware connection.

Let's execute a command on `/dev/tcp/<host>/<port>` pseudo-device file, to let Bash open a [TCP](https://en.wikipedia.org/wiki/Transmission_Control_Protocol) connection to the associated socket.

In this example, we try to connect at target IP 10.0.0.21 to port 22/TCP.
The command will print out “open”, if we get any replay from the target.
```bash
timeout 0.3 bash -c "echo >/dev/tcp/10.0.0.21/22" && echo "open" || echo "closed"
```

There is also an `/dev/udp` pseudo-device, but because [UDP](https://en.wikipedia.org/wiki/User_Datagram_Protocol) uses “stateless” connection, we won't get any reply from the UDP port. So we can't check for open UDP ports.

With this one-liner, you can quickly check multiple targets for open ports.

{{< highlight bash "hl_lines=1,lineAnchors=1" >}}
for i in {1..20}; do timeout 0.3 bash -c "echo >/dev/tcp/10.0.0.${i}/22" && echo "10.0.0.${i}: open" || echo "10.0.0.${i}: closed"; done
10.0.0.1: open
10.0.0.2: closed
10.0.0.3: closed
10.0.0.4: closed
10.0.0.5: closed
10.0.0.6: closed
10.0.0.7: closed
10.0.0.8: closed
10.0.0.9: closed
10.0.0.10: closed
10.0.0.11: closed
10.0.0.12: closed
10.0.0.13: closed
10.0.0.14: closed
10.0.0.15: closed
10.0.0.16: closed
10.0.0.17: open
10.0.0.18: open
10.0.0.19: open
10.0.0.20: closed
{{< /highlight >}}

### References
- [Advanced Bash-Scripting Guide: Chapter 29. /dev and /proc](https://tldp.org/LDP/abs/html/devref1.html), tldp.org.
- [TCP Port Scanner in Bash](https://catonmat.net/tcp-port-scanner-in-bash), catonmat.net.
- [3.6 Redirections](https://www.gnu.org/software/bash/manual/html_node/Redirections.html), gnu.org.
- [Writing a pseudo-device driver on Linux](https://lyngvaer.no/log/writing-pseudo-device-driver), lyngvaer.no.
