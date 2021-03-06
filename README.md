# packetPlotter

packetPlotter maps the path of a packet across an IP network in real-time.  It displays markers to specify the geographic location of each hop along the path from the source to the destination.  In addition, it includes links from each hop to the next and displays the average latency of each link (links are colored according to latency).

Color scale:

smaller latencies -----------------------------------------------------------------------------------> larger latencies
![Alt text](colormap.png?raw=true "colormap")

Path of a packet from Berkeley, CA, USA to Zanzibar University in Tanzania http://www.zanvarsity.ac.tz/

![Alt text](Zanzibar.png?raw=true "Path of a packet from Berkeley, CA, USA to Tanzania http://www.zanvarsity.ac.tz/")

Path of a packet from Berkeley, CA, USA to www.facebook.com that passes through Singapore and Ireland

![Alt text](Hop.png?raw=true "Path of a packet from Berkeley, CA, USA to Tanzania http://www.zanvarsity.ac.tz/")

Future work: run the routes a few times to make the routes stable and the estimated latencies more accurate

