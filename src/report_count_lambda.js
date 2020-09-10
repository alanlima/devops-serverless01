const { 
    getSsmParameter, 
    getCustomersCount,
    AWS
 } = require('./common');

const INSERT_EVENT_NAME = "INSERT";
exports.handler = async function handler(event, context) {
    console.log('report_cusotmers_handler:', event);

    console.info(`filtering records to eventName=${INSERT_EVENT_NAME}`);

    const recordsInserted = event.Records.filter(r => r.eventName === INSERT_EVENT_NAME);

    if (recordsInserted.length === 0) {
        console.info('no new records.')
        return { message: 'no new records... do not notify.', emailSent: false };
    }

    console.info(`found ${recordsInserted.length} new record(s)`);

    const customersCount = await getCustomersCount();

    console.info(`total customers count: ${customersCount}`);

    const message = `
    Records Added: ${recordsInserted.length}
    Number of records: ${customersCount}`;

    await publishReport(message);

    return { message: 'sent notification with customers count.', emailSent: true };
}

async function publishReport(message) {
    console.log('publishing message: ', message);
    
    const topicArn = process.env.SNS_TOPIC_ARN
    
    const params = {
        Message: message,
        TargetArn: topicArn,
        Subject: '[devops-academy] Customers Report'
    }

    const snsClient = new AWS.SNS();

    const data = await snsClient.publish(params).promise();

    console.log(`Message sent to the topic ${topicArn}`);
    console.log(`MessageID ${data.MessageId}`);
}