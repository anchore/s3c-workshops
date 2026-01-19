# Monitoring an Anchore Deployment Using Prometheus and Grafana

## Prerequisites

- [ ] Laptop with docker logged in (PAT login valid/accessible)

- [ ] Docker-compose/Docker daemon

- [ ] Able to pull Prometheus (docker.io/prom/prometheus:latest)

- [ ] Able to pull Grafana (docker.io/grafana/grafana:latest)


## What are Metrics?

‘Metrics’ are simply numerical measurements. When working with metrics, you may also run into the term ‘time-series’ which just means a recording of changes in measurements over time. The recording of metrics can be incredibly useful and important for modern applications. They will allow for proactive issue detection and predictability of the application behaviour to prepare and when using alerting mechanisms, can act as an early warning system. Metrics play an important role in understanding why your application is working a certain way.\
When issues are experienced, taking a look at historical metrics can assist in Root Cause Analysis(RCA) by pinpointing the exact time(s) and context that which something occurred.


## Benefits of Monitoring Anchore

The main benefit is simply gaining a better understanding of what is going on inside your deployment. Monitoring tools such as Prometheus allow you to stay up to date on important metrics surrounding your deployment health, uptime, scan/analysis time, and resource usage to allow for tight tuning of the deployment specific for your infrastructure to reduce issues with running out of resources, or to reduce and optimize the costs of the deployment, or to optimize scaling capacity. 

- Proactive Issue Detection

- Scalability Management and Performance Optimization

- General observability of the environment and interactions between services

- Cost Management

Some examples of use cases around these are the following;\
\
A customer is complaining about slow scanning times in Anchore. This can be tracked ‘manually’ by browsing the analyzer logs and following the thread logs for a specific image to track when it is de-queued and pulled into the analyzer, this would look something like the following; 


### Lab Exercise 1: Tracing Image Analysis via Analyzer Logs

1. Add [docker.io/library/postgres:latest](http://docker.io/library/postgres:latest) (or any official image from dockerhub) into your deployment

<!---->

    $ anchorectl image add docker.io/library/postgres:latest

     ✔ Added Image                                                                                    docker.io/library/postgres:latest
    Image:
      status:           analyzed (active)
      tag:              docker.io/library/postgres:latest
      digest:           sha256:07ad6d6385313c68c8acd575ac8cc0d73921cdea430afd3dc228782ee1f5a73b
      id:               69092dbdec0ddd9e1860e67be2c040b83cce9ffec785b2f740f34e8eb43178e5
      distro:           debian@12 (amd64)
      layers:           14

2. Grab the logs for the analyzer pod.

<!---->

    docker logs anchore-570-analyzer-1

Now, there are a few ways to find the events for the analysis of this image, and the method you choose may depend on how busy the analyzer has been. You can manually scroll through the logs until you find the events for analysis of the image. This may be a difficult way to do things if you have a lot of logs and activity in the analyzer.\
The preferred method would be searching for the image tag which can be done using a grep in the docker command.



    $ docker logs anchore-570-analyzer-1 | grep docker.io/library/postgres -m 1

    [service:anchore-enterprise-analyzer] [2024-08-18T12:59:13.569659+00:00] [MainProcess] [Thread-55181] [INFO] [anchore_enterprise.services.analyzer.analysis/perform_analyze():280] | performing analysis on image: ['admin', 'docker.io/library/postgres@sha256:07ad6d6385313c68c8acd575ac8cc0d73921cdea430afd3dc228782ee1f5a73b', 'docker.io/library/postgres:latest']

I’ve limited it to one line as all we need from this is the thread number, as this will allow me to show how the analysis process can be traced in the next step. Copy the thread number you see, in my case it is `[Thread-55181]`

3. Get the logs again, but this time, grep for the copied thread number.

<!---->

    $ docker logs anchore-570-analyzer-1 | grep Thread-55181

    [service:anchore-enterprise-analyzer] [2024-08-18T12:59:13.476831+00:00] [MainProcess] [Thread-55181] [INFO] [anchore_enterprise.services.analyzer.analysis/process_analyzer_job():415] | image dequeued for analysis: admin : sha256:07ad6d6385313c68c8acd575ac8cc0d73921cdea430afd3dc228782ee1f5a73b
    [service:anchore-enterprise-analyzer] [2024-08-18T12:59:13.569659+00:00] [MainProcess] [Thread-55181] [INFO] [anchore_enterprise.services.analyzer.analysis/perform_analyze():280] | performing analysis on image: ['admin', 'docker.io/library/postgres@sha256:07ad6d6385313c68c8acd575ac8cc0d73921cdea430afd3dc228782ee1f5a73b', 'docker.io/library/postgres:latest']
    [service:anchore-enterprise-analyzer] [2024-08-18T12:59:13.575234+00:00] [MainProcess] [Thread-55181] [INFO] [anchore_enterprise.services.analyzer.analysis/perform_analyze():287] | analyzing image: docker.io/library/postgres@sha256:07ad6d6385313c68c8acd575ac8cc0d73921cdea430afd3dc228782ee1f5a73b
    [service:anchore-enterprise-analyzer] [2024-08-18T12:59:13.585940+00:00] [MainProcess] [Thread-55181] [INFO] [anchore_enterprise.services.analyzer.localanchore_standalone/pull_image():679] | Downloading image docker.io/library/postgres@sha256:07ad6d6385313c68c8acd575ac8cc0d73921cdea430afd3dc228782ee1f5a73b for analysis to /analysis_scratch/17b02621-8234-4815-93cc-1ae10fe6a75f/raw
    [2024-08-18T13:00:32.494336+00:00] [MainProcess] [Thread-55181] [INFO] [anchore_enterprise.services.analyzer.analysis/process_analyzer_job():508] | analysis complete: admin : sha256:07ad6d6385313c68c8acd575ac8cc0d73921cdea430afd3dc228782ee1f5a73b

I have gone ahead and removed a large portion of the lines in the output to reduce the size for this document, however, in your output, you should see the full process that the analyzer goes through when analyzing the image from the moment the image is pulled from the queue to the moment the image data is uploaded and the analysis is complete. Each event has the thread number in the log line, which means that by knowing which thread the analysis starts processing on, we can grep for it and track the entire process. Knowing this, we can use the datetime-stamps in the log lines to work out how long an image takes to analyze, the time of the image getting de-qued was 12:59:13 and the time that the analysis completed was 13:00:32. This means that the image just over 1 minute and 19 seconds to complete. This can be valuable to know, however, can be somewhat of an awkward process to complete to find the analysis time for an image as well as being difficult to visualize.

But in Prometheus, we can view a specific set of metrics for Analysis time such as; **_anchore\_analysis\_time\_seconds\_sum / anchore\_analysis\_time\_seconds\_count_**




## Target Audience

Internally, this is a benefit for everyone running test environments/their own deployments of Anchore. It will allow you to view and modify/create different metrics to measure things such as resource usage of any specific service and ultimately give you the maximum level of control over your deployment, as well as replicating and troubleshooting any potential customer issues.\
Externally, for customers, it will allow them to gain a better insight into their deployment - are analyzers scanning images too slowly? Are the resources for a specific service tuned correctly?\
Things like this will allow them to optimize their cost-performance ratio.


## ![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXcIeayFM6Wq71Tyx_e4D6i4vPhsFLLm1pA0dd6gCllsJmkuFCramC0YuG2bcHg6XZMcFEgWqV6UGPirraSZABBcld2srrgqCKI_8IOZaVxmg2oY4Tj4GlwXevpp67ohP-zqWWa1MP1gU3KEdmqZacy3Xtw?key=yhcfB7su20ibDNRSMmeo7A)

Built-in Compose Monitoring

These give a very high-level overview of the given metrics, but these are for the overall deployment only, meaning none of these graphs will be accurate down to the actual service level i.e How much max memory and/or CPU is analyzer 1 of x using?


## Monitoring Using the Event Logs in CLI

The Event Log allows the user to monitor async events across the full spectrum of Anchore services. This is extremely useful for troubleshooting as you can trace an Event Activity throughout the Docker desktop deployment and discover any errors that might be run into along the way. The error codes/messages are usually a little more descriptive in the logs which often leads to a better idea of the root issue. You can also pinpoint exact errors and view errors by the specific error type. Now, being in the support team, we usually analyse logs through text files generated by the support-bundle. However, for a deployment that you have access to via anchorectl, we have extremely useful tools to make navigating the event logs much smoother.
\


## ![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXfr3J8ybtiTVMnLgQZwuvIn6RZoufyH8yN0CoaUvzDwn80MTfUfDbxjBvri8eKsxfMwveKb7fU6nuiGjYByt8amEMZpoA33LUru8JdOyi4AaVOGHXeypsdJ2gBUxRZ--MHmDgmC6rWpZQI2UHKq8XUa4Zmv?key=yhcfB7su20ibDNRSMmeo7A)


## What is Prometheus?

Prometheus stores data and collects/stores time-series data from different sources (exporters), in our case, Anchors services are the exporters. Prometheus acts like a data library, organizing and saving metrics over time and allows for easy retrieval and querying of this data.

Prometheus Metric Types

Prometheus metric names can be anything, but with the Anchore services, we try to keep them as close to describing what the metric itself is, as much as possible. For example, ‘anchore\_analyzer\_status’ will be the analyzer's status.

- Counter: simple type that starts at 0 and can only ever increase.

  - At time T, the total number of images analyzed by this analyzer since it started was N

* Gauge: simple type that is a just a number(and unlike counters can increase AND decrease) - often visualized directly:

  - At time T, the images\_to\_analyze queue had N tasks in it

- Histogram: less-simple type that is used by PromQL/Grafana to display statistical properties of a metric, like percentiles, rates, distributions and deviations, and other useful functions. Each histogram metric automatically comes with two related metrics, both counters, for the \_sum and \_count, which are useful/easy to use on their own.




## Lab Exercise 2: Enabling Prometheus Monitoring in Existing Compose Deployment

Now, ensure that your Docker deployment is up and running as expected. Once you have confirmed this, you must enable the Prometheus monitoring tool by setting the correct value in the docker-compose.yaml.

<https://docs.anchore.com/current/docs/deployment/docker_compose/#optional-enabling-prometheus-monitoring>

<https://docs.anchore.com/current/docs/deployment/anchore-prometheus.yml>



1. Uncomment(or add and then uncomment) the following section at the bottom of the docker-compose.yaml file:

```

#  # Uncomment this section to add a prometheus instance to gather metrics. This is mostly for quickstart to demonstrate prometheus metrics exported
#  prometheus:
#    image: docker.io/prom/prometheus:latest
#    depends_on:
#      - api
#    volumes:
#      - ./anchore-prometheus.yml:/etc/prometheus/prometheus.yml:z
#    logging:
#      driver: "json-file"
#      options:
#        max-size: 100m
#    ports:
#      - "9090:9090"
#
```

2. For each service entry in the docker-compose.yaml, change the following to enable metrics in the API for each service

```

ANCHORE_ENABLE_METRICS=false
```

to

```

ANCHORE_ENABLE_METRICS=true
```

3. Download the example prometheus configuration into the same directory as the docker-compose.yaml file, with name _anchore-prometheus.yml_:

```

curl https://docs.anchore.com/current/docs/quickstart/anchore-prometheus.yml > anchore-prometheus.yml
docker compose up -d
```

4. **Result**: You should see a new container started and can access prometheus via your browser on `http://localhost:9090`


## Lab Exercise 3: Visualizing & Reading Metrics 

Visualizing metrics using various custom graphs can enhance clarity, speed up analysis by the user, and make the data more accessible and actionable, which is often more beneficial than relying solely on raw Prometheus queries. Graphs and dashboards can make it easier to comprehend some of the more complex data patterns and trends. Seeing the data visually can highlight relationships, anomalies, and trends that might be difficult to spot through raw queries alone.

Lab Exercise

1. Add a few images to your deployment from docker.io and then head over to your Prometheus dashboard at localhost:9090.

2. Click on the ‘’Open Explorer’ Globe next to the Execute button and then select ‘anchore\_analyzer\_status’

3. Hit ‘Execute’ and take a look at the graph.

4. Summit Question 1: Describe what the graph is showing.. \


![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXeejiVpCOHfC1Gom-DmfeyNlJTOVgjusyVqksRf_3mfIUYRWw5jia5FYaGEciWmnni3mspXpBFrBBoi4RKa-EARLtRCbIhvAZMQVRfhz5XmelS-k7Ir5RmarX8pzahwKEDRcLAIUDbnn1bKp1nFylxKwYZH?key=yhcfB7su20ibDNRSMmeo7A)

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXdx71XGNiVOeHiKeHbW2B2O0aqmbmwkZC1jh3qFT3lFOEWtUfNp_9_F8kF7l_Monedqh9NNX1w25sjzaIlucIZgm1FfnTHDt_4vC-75O6ikLJ8F0mCjRCTumZuonOSAlyLTLNH_vkHxnL9ihgB4Y9AjBPs?key=yhcfB7su20ibDNRSMmeo7A)

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXclRXj5Re78_3zOb0Ym_Rvwb3SEYVdptuFUjHCAVj_kCt4uiDlW8rlQ3Z8wLih4EATgBcx8sVfB2SESATvO7O2EUiPtb3_lCVf976YM39CTuMq6r9mxXRziZCTg0K0ijP5zo0YaSwhp_As38E1HsLy8A_E-?key=yhcfB7su20ibDNRSMmeo7A)

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXdleqhtTVZ5y-VZhAWpk1cPY3Bx4xZDVylHnKKaeNAWh8BG54_jA7551aLsrf8Z3Z1vOf24t_MjunuNvP486Z5Vh4ne-njdAbOR5iD4BFSQMO5Y5fdElmXt5Saoq0iy3U7IUSsNeCzVHRz2Z5Rtur2uF8RV?key=yhcfB7su20ibDNRSMmeo7A)

5. Summit Question 2: Can you describe/draw what this would look like if the deployment had 2 analyzers and 1 image was added for analysis, taking 3mins to process.




## What is Grafana?

You may be aware of Grafana, or have at least heard of it. It is a separate tool from Prometheus, but they work seamlessly together to create visualizations and dashboards of metrics stored in Prometheus by consuming the data that Prometheus stores. Grafana queries the Prometheus database to retrieve the metrics you want to visualize. It is an open-source platform used for this purpose and offers an intuitive interface for designing custom dashboards, graphs, and visualizations.


## Lab Exercise 4: Enabling Grafana in Existing Compose Deployment

1. Add the snippet below to the volumes section at the top of your docker-compose.yaml. This will create and mount an external volume for grafana.

<!---->


      grafana-db-volume:
        external: false

**Tip**: If you don’t set this volume correctly, when you add the configuration in the next step and try to run docker-compose up -d you will see the following error as the volume is not being defined; 

<!---->


    $ docker-compose up -d
    service "grafana" refers to undefined volume grafana-db-volume: invalid compose project

2. Add the below snippet under the prometheus configuration in the docker-compose.yaml.

<!---->

      grafana:
        image: docker.io/grafana/grafana:latest
        depends_on:
          - api
          - prometheus
        volumes:
          - grafana-db-volume:/var/lib/grafana
    #      - ./prometheus_datasource_config.yaml:/etc/grafana/provisioning/datasources/anchore.yaml:z
        logging:
          driver: "json-file"
          options:
            max-size: 100m
        ports:
          - "3001:3000"

3. Run docker-compose up -d and notice there is a running service now called 'grafana'.

Point browser at <http://localhost:3001>.

4. Login with;\
   Username: admin\
   Password: admin\
   ![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXc6G9H2h7TNM35Wt-oIL-cUy7KNiKe1_6wMnt94zdsL3i_bmr0omdo6SrZ8SId41zgrZ6bQeNH1LW152h5XkA-6pyYdtv0tjr6vZcfJrrtj_eYMjfLlKfvb1dLwH8v4ykF5LzWKipO-gFsjInQo0Q3bVYE?key=yhcfB7su20ibDNRSMmeo7A)

5. Select ‘add first data source’ - - make sure you are adding a data source and not a dashboard;

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXcAUkIKR9iCnhgiBi1DSEAjgWEoVsm2B6FEsi4X3n6ig5ocJ5HgZDVz2HGFPwD6YkqILKGjPjSyH_9GCffk23wnK54iMp5thY45nmM-2U_Hs-bV-bB1DPdva9cPNVeSkaJH2yRFT4uFEMu0Zn40y6M8wrc?key=yhcfB7su20ibDNRSMmeo7A)

6. Put in your Prometheus endpoint ‘http\://prometheus:9090’;

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXfFxgsSaaRN1lxg3d5q2geJczGIkV1pjhYIl4ZezEXzJCABC6hDkPESjj6d5N2ooKzJw0QMwX6Jo1Qr10U0K3QWTzRnDNi-zg-87nx6LX3_r5qyf5BpuGwPFXIYtBvRZiLlzMdmIYwZkCI8z9qNvNUCy-QI?key=yhcfB7su20ibDNRSMmeo7A)

7\. Click ‘Save & Test’, then click ‘create a dashboard’

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXcM4KpZJroIgzpFHvc-SSmkQ5n9vtfawQpMf-gAGDZATN2MPbgkq2gLQhXJ9OVgbzspASW3aVjN3Fc1ZDOxFE7TUU7gfs8QNfntHJM23XWpXRJnR19o8pTBzwdKq4GGSMxyiAozPymORpNP_twV0Hrva5x7?key=yhcfB7su20ibDNRSMmeo7A)\
8\. Click ‘import dashboard’

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXe45nOhuueTAq63-32dLhPppNAjj-nWwo9nkaCr-KNorrr1ThkEHYgI-tP3EhVwNu4lsYXZOh8T4bhDfcS_XmJqS7TIpD9pgoSjz9acda-k574gaUwmxA_uYJ3wP3FBlQ0VoW1h6UfAnFs9x9qW8mUmYAb7?key=yhcfB7su20ibDNRSMmeo7A)

9\. Upload the included file ‘grafana\_dashboard\_enterprise.json’

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXfymBFMDvaLmgrJOZgeBkUhhJzKr6908duvSON_j_eXlo2pwUOPi41ThnZUtWi-QBV5M2igNzRiqbovncOJZSfIqED6Tu4qzIehjfYaeqF0VNeSxWtaYz9wW_T1EIIUhZhOo0B81LxZV-OpLtid6jYKbcN0?key=yhcfB7su20ibDNRSMmeo7A)

10\. Select the prometheus data source from the dropdown and click ‘import’

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXd-wKf76-KQj-kaxYs-WABx5dmhPj3Dddl6YxPhaJc51doI-vHanncxu7UatWffQvXtIXVQOK5uhmJ7pFJN9yzcbrYXcfyTJ0c8KLOTwUfprkFImn_9_d-icfUSCIfT--r1bT61WYe9OQjaFnHm0EWuBPup?key=yhcfB7su20ibDNRSMmeo7A)

11\. Have fun!

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXfu-DPO2zEV5POaNVS9IvDlAU-VtSXFHWuH0un5sEEvH8WbQv7MPYntJ006fCEm9V83fv4OVHhJ5VZA_4UWQXvWsfq8uXEnYo-kgv5NSh_eQ46yavhFk-nuLhKDcJVv77Ocxv6Ef-wgP71CfGxPoB9EH0_6?key=yhcfB7su20ibDNRSMmeo7A)




## Grafana - A Customer Use Case

Once you have Grafana loaded up, you should see a set of graphs as part of the default dashboard. Taking a look down, you will find graphs for CPU and Memory - two items that are commonly mentioned by customers and can often be found to cause pain points when resourcing causes issues in a deployment i.e. services running out of memory. 

If we take a look at the example screenshot below, you will see 4 graphs which we will briefly walk through understanding and see how they relate to each other and how common customer asks tie into them and can be used to gather more information for customers.\
\
You can see that I started scanning images at around 14:30 where the Analyzer Status has noticeable activity in the graph as the status changes. Corresponding with this, if you take a look at each of the other graphs around the same time period, you will see how they each ‘react’ to processing images. For example, the API CPU usage spikes substantially while all 3 images were added(1 scanning and 2 queued) but then falls again as you can see each subsequent scan complete. You can see the key below the CPU graph, which will allow you to choose the service that you wish to see the graph for - the image currently depicts just the API service.

You can see the same for the Memory: Process RSS graph bottom right with the lines for each service all plotted on the graph - you can see that the catalog is constantly the most memory-hungry service running at 3GB and the policy engine at 1GB, but you will notice that the Memory: Process Type RSS graph top right contains just 1 single line. This line is the sum of the count parameters??

![](https://lh7-rt.googleusercontent.com/docsz/AD_4nXdn4IHxwTNgQYuMOONJwIoN0qVAuh4R1hkV-DmHh1kcVkHQakaEQo_YlwL1Dg2klXECMPiOiLgl4zWfCuxi_25yZSfvXQZ1IR1YFavWljoXyPzalVHfPgMDM61j3jNrTtyrnxikm-KoLcWgMQo71x-SiOg?key=yhcfB7su20ibDNRSMmeo7A)



Continued Learning;\
[Prometheus Primer](https://docs.google.com/document/d/1Fai0cuk7IojYs6VzAhZ2kUfo0NRDkFJf-9V8LxaqF5U/edit) - Some more detailed information on understanding metrics and how to combine them.

