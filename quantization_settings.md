symmetric quantization and layer-fused quantization

output shift = scale of output of last layer + weight scale - scale of output of this layer

scale = 2^(n-1-log(round(range))



|output of layer|layername|rounded range|scale|output shift|weight range|weight scale|
|-|-|-|-|-|-|-|
|0.9725|image|1|2^15||||
|2.2771|conv1 depth|4|2^13|>>15+13-13|2.5312|2^13|
|3.4666|conv1 point|4|2^13|>>13+14-13|1.4708|2^14|
|3.7338|conv2 depth|4|2^13|>>13+14-13|0.8829|2^15|
|3.9521|conv2 point|4|2^13|>>13+14-13|0.7728|2^15|
|4.1434|conv3 depth|4|2^13|>>13+15-12|0.7404|2^15|
|3.3134|conv3 point|8|2^12|>>12+15-13|0.7719|2^15|
|3.8975|fc1|4|2^13|>>13+15-11|0.2043|2^15|
|10.23|fc2|16|2^11|>>13+15-11|0.3785|2^15|



