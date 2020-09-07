echo $SNS_REPORT_TOPIC_ARN

if [ -z "$SNS_REPORT_TOPIC_ARN" ]; then
    echo "Missing env: SNS_REPORT_TOPIC_ARN"
    exit 1
fi

aws sns subscribe \
    --topic-arn $SNS_REPORT_TOPIC_ARN \
    --protocol email \
    --notification-endpoint alima@outlook.com