# comp5123m

## Server

=========== TASK D: EXPERIMENTAL LOAD TESTING (CLOUD) ===========
 i Ensure you have your Grafana dashboard open to watch the Cloud VM metrics.

 i TEST 1: ICMP Ping (Baseline Cloud Latency)
   > Pinging the VNF Pod directly (K8s Services drop ICMP traffic by design).
 ? Run Ping test? (y/N): y
 i Extracted Cloud Firewall Pod IP: 10.244.0.27
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
64 bytes from 10.244.0.27: seq=2 ttl=64 time=0.088 ms
64 bytes from 10.244.0.27: seq=3 ttl=64 time=0.106 ms
64 bytes from 10.244.0.27: seq=4 ttl=64 time=0.080 ms

--- 10.244.0.27 ping statistics ---
5 packets transmitted, 5 packets received, 0% packet loss
round-trip min/avg/max = 0.077/0.101/0.154 ms
pod "ping-client" deleted from default namespace
 ✓ Ping test complete. Record the Cloud latency (ms) for your report.

 i TEST 2: iperf3 (TCP Throughput via Service Chain)
   > Floods the VNF with TCP packets to find the maximum bandwidth ceiling.
 ? Run iperf3 test for 20 seconds? (y/N): y
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   152 MBytes  1.27 Gbits/sec   16    472 KBytes
[  5]   1.00-2.00   sec   126 MBytes  1.06 Gbits/sec    8    547 KBytes
[  5]   2.00-3.00   sec   119 MBytes   999 Mbits/sec   12    574 KBytes
[  5]   3.00-4.00   sec   125 MBytes  1.05 Gbits/sec   12    769 KBytes
[  5]   4.00-5.00   sec   129 MBytes  1.08 Gbits/sec   10    807 KBytes
[  5]   5.00-6.00   sec   131 MBytes  1.10 Gbits/sec   14    848 KBytes
[  5]   6.00-7.00   sec   136 MBytes  1.14 Gbits/sec   15    848 KBytes
[  5]   7.00-8.00   sec   126 MBytes  1.06 Gbits/sec   16    848 KBytes
[  5]   8.00-9.00   sec   140 MBytes  1.17 Gbits/sec   18    848 KBytes
[  5]   9.00-10.00  sec   148 MBytes  1.24 Gbits/sec   13    848 KBytes
[  5]  10.00-11.00  sec   140 MBytes  1.17 Gbits/sec   20    848 KBytes
[  5]  11.00-12.00  sec   149 MBytes  1.25 Gbits/sec   21    848 KBytes
[  5]  12.00-13.00  sec   132 MBytes  1.11 Gbits/sec   15    848 KBytes
[  5]  13.00-14.00  sec   135 MBytes  1.13 Gbits/sec   13    848 KBytes
[  5]  14.00-15.00  sec   142 MBytes  1.20 Gbits/sec   10    848 KBytes
[  5]  15.00-16.00  sec   125 MBytes  1.05 Gbits/sec    9    848 KBytes
[  5]  16.00-17.00  sec   130 MBytes  1.09 Gbits/sec   14    848 KBytes
[  5]  17.00-18.00  sec   130 MBytes  1.09 Gbits/sec   14   1.01 MBytes
[  5]  18.00-19.00  sec   135 MBytes  1.13 Gbits/sec   10   1.06 MBytes
[  5]  19.00-20.00  sec   138 MBytes  1.15 Gbits/sec   13   1.06 MBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-20.00  sec  2.63 GBytes  1.13 Gbits/sec  273             sender
[  5]   0.00-20.04  sec  2.62 GBytes  1.12 Gbits/sec                  receiver

iperf Done.
pod "iperf-client" deleted from default namespace
 ✓ iperf3 test complete. Record the Cloud Bitrate (Mbits/sec).


 i TEST 3: wrk (HTTP API Load Simulation)
   > Simulates 100 concurrent 5G users hammering the VNF Gateway with requests.
 ? Run wrk HTTP test for 30 seconds? (y/N): y
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.

  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   151.45ms   48.52ms 456.83ms   68.95%
    Req/Sec   163.77     83.33   540.00     51.15%
  19542 requests in 30.06s, 21.13MB read
Requests/sec:    650.18
Transfer/sec:    720.03KB
pod "wrk-client" deleted from default namespace
 ✓ wrk test complete. Record the Cloud Requests/sec and Latency.

## Client

=========== TASK D: EXPERIMENTAL LOAD TESTING (EDGE) ===========
 i Ensure you are watching the Edge VM metrics on your Cloud Grafana dashboard.

 i TEST 1: ICMP Ping (Baseline Edge Latency)
   > Pinging the Edge Firewall Pod directly.
 ? Run Ping test? (y/N): y
 i Extracted Firewall Pod IP: 10.42.0.22
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
64 bytes from 10.42.0.22: seq=1 ttl=64 time=0.086 ms
64 bytes from 10.42.0.22: seq=2 ttl=64 time=0.072 ms
64 bytes from 10.42.0.22: seq=3 ttl=64 time=0.076 ms
64 bytes from 10.42.0.22: seq=4 ttl=64 time=0.078 ms

--- 10.42.0.22 ping statistics ---
5 packets transmitted, 5 packets received, 0% packet loss
round-trip min/avg/max = 0.072/0.086/0.122 ms
pod "ping-client" deleted from default namespace
 ✓ Ping test complete. Record the Edge latency (ms).

 i TEST 2: iperf3 (TCP Throughput via Service Chain)
   > Floods the Edge Firewall with TCP packets to test the K3s bandwidth ceiling.
 ? Run iperf3 test for 20 seconds? (y/N): y
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   193 MBytes  1.62 Gbits/sec    8    441 KBytes
[  5]   1.00-2.00   sec   174 MBytes  1.46 Gbits/sec    3    441 KBytes
[  5]   2.00-3.00   sec   184 MBytes  1.54 Gbits/sec    6    441 KBytes
[  5]   3.00-4.00   sec   179 MBytes  1.50 Gbits/sec    7    441 KBytes
[  5]   4.00-5.00   sec   183 MBytes  1.54 Gbits/sec   10    441 KBytes
[  5]   5.00-6.00   sec   175 MBytes  1.47 Gbits/sec    3    441 KBytes
[  5]   6.00-7.00   sec   169 MBytes  1.42 Gbits/sec    8    441 KBytes
[  5]   7.00-8.00   sec   186 MBytes  1.56 Gbits/sec   11    441 KBytes
[  5]   8.00-9.00   sec   182 MBytes  1.52 Gbits/sec    6    441 KBytes
[  5]   9.00-10.00  sec   199 MBytes  1.67 Gbits/sec    9    441 KBytes
[  5]  10.00-11.00  sec   194 MBytes  1.63 Gbits/sec   10    486 KBytes
[  5]  11.00-12.00  sec   198 MBytes  1.66 Gbits/sec    7    486 KBytes
[  5]  12.00-13.00  sec   202 MBytes  1.70 Gbits/sec    8    486 KBytes
[  5]  13.00-14.00  sec   206 MBytes  1.73 Gbits/sec    7    486 KBytes
[  5]  14.00-15.00  sec   199 MBytes  1.67 Gbits/sec    9    486 KBytes
[  5]  15.00-16.00  sec   189 MBytes  1.59 Gbits/sec    8    486 KBytes
[  5]  16.00-17.00  sec   202 MBytes  1.69 Gbits/sec   10    486 KBytes
[  5]  17.00-18.00  sec   187 MBytes  1.57 Gbits/sec    9    535 KBytes
[  5]  18.00-19.00  sec   195 MBytes  1.63 Gbits/sec   11    535 KBytes
[  5]  19.00-20.00  sec   199 MBytes  1.67 Gbits/sec    9    535 KBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-20.00  sec  3.71 GBytes  1.59 Gbits/sec  159             sender
[  5]   0.00-20.01  sec  3.70 GBytes  1.59 Gbits/sec                  receiver

iperf Done.
pod "iperf-client" deleted from default namespace
 ✓ iperf3 test complete. Record the Edge Bitrate (Mbits/sec).

 i TEST 3: wrk (HTTP API Load Simulation)
   > Simulates 100 concurrent users hitting the Edge Service Chain.
 ? Run wrk HTTP test for 30 seconds? (y/N): y
All commands and output from this session will be recorded in container logs, including credentials and sensitive information passed through the command prompt.
If you don't see a command prompt, try pressing enter.
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    90.83ms   25.62ms 212.43ms   66.13%
    Req/Sec   274.53     46.48   484.00     75.40%
  32860 requests in 30.09s, 35.54MB read
Requests/sec:   1091.91
Transfer/sec:      1.18MB
pod "wrk-client" deleted from default namespace
 ✓ wrk test complete. Record the Edge Requests/sec and Latency.
