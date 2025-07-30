.PHONY: all sonarqube-usage-collector user-data-collector gitlab-usage-collector athena-view-creator clean

all: sonarqube-usage-collector user-data-collector gitlab-usage-collector athena-view-creator

sonarqube-usage-collector:
	cd modules/sonarqube-usage-collector/lambda && \
	zip lambda.zip collector.py

user-data-collector:
	cd modules/user-data-collector/lambda && \
	zip lambda.zip collector.py

gitlab-usage-collector:
	cd modules/gitlab-usage-collector/lambda && \
	zip lambda.zip collector.py

athena-view-creator:
	cd modules/athena-view-creator/lambda && \
	zip lambda.zip collector.py

clean:
	rm -f modules/sonarqube-usage-collector/lambda/lambda.zip \
	      modules/user-data-collector/lambda/lambda.zip \
	      modules/gitlab-usage-collector/lambda/lambda.zip \
	      modules/athena-view-creator/lambda/lambda.zip
