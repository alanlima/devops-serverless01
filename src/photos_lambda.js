// const AWS = require('aws-sdk');
const {
    getCustomerByEmail,
    getTableName,
    AWS
} = require('./common');

async function handler(event, context) {
    console.log('photos handler event', event);

    for(let record of event.Records) {
        try {
            await processRecord(record);
        } catch(e) {
            console.warn('could not process record... skipping', e);
        }
    }
}

async function processRecord(record) {
    console.info('processing record...', record);
    const {
        bucketName, fileName
    } = extractFileInfo(record);

    console.info(`handling file ${fileName} at ${bucketName}`);

    const customerEmail = parseCustomerEmail(fileName);
    const customer = await getCustomerByEmail(customerEmail);

    if(customer == undefined) {
        console.log('customer not found..');
        return;
    }

    console.log('found customer: ', JSON.stringify(customer));

    const photoLocation = `s3://${bucketName}/${decodeURIComponent(fileName)}`

    await updatePhotoLocation(customer, photoLocation);

    await sendWelcomeEmail(customer, photoLocation);
}

async function updatePhotoLocation(customer, photoLocation) {
    const customerId = customer.id.S;
    console.info(`updating photo location to ${photoLocation} for customer ${customerId}`);
    const dynamoClient = new AWS.DynamoDB();

    const params = {
        TableName: await getTableName(),
        Key: {
            id: { 'S': customerId }
        },
        UpdateExpression: "set photo_location=:p",
        ExpressionAttributeValues: {
            ":p": { 'S': photoLocation }
        },
        ReturnValues: "UPDATED_NEW",
    }

    const updateResponse = await dynamoClient
        .updateItem(params)
        .promise();
    
    console.info('update photo response: ', updateResponse);

    return updateResponse;
}

async function sendWelcomeEmail(customer, photoLocation) {
    const customerEmail = customer.email.S;
    const customerName = `${customer.lastname.S}, ${customer.firstname.S}`;
    console.info(`sending welcome e-mail`);

    const senderName = process.env.SENDER_NAME || 'DevOps Academy';
    const senderMail = process.env.SENDER_EMAIL;
    
    if(senderMail == undefined) {
        console.warn("You must specify SENDER_NAME and SENDER_EMAIL to send the welcome e-mail.");
        return;
    }

    const bodyHtml = `
    <html>
        <body>
        <h1>Hello ${customerName}</h1>
        <p>This is a confirmation e-mail that your photo was uploated to <strong>${photoLocation}</strong>.</p>
        </body>
    </html>`;

    const sender = `${senderName} <${senderMail}>`;
    const Charset = "UTF-8";

    try {
        const sesClient = new AWS.SESV2();
        const response = await sesClient.sendEmail({
            FromEmailAddress: sender,
            Destination: {
                ToAddresses: [ customerEmail ]
            },
            Content: {
                Simple: {
                    Body: {
                        Html: {
                            Charset,
                            Data: bodyHtml
                        }
                    },
                    Subject: {
                        Charset,
                        Data: '[devops-academy] Photo Upload Confirmation'
                    }
                }
            }
        }).promise();

        console.info(`Email sent! Message Id: ${response.MessageId} `)
    } catch(e) {
        console.warn('Error on sending e-mail', e);
    }
}


const extractFileInfo = record => ({
        bucketName: record.s3.bucket.name,
        fileName: record.s3.object.key
});

const parseCustomerEmail = fileName => decodeURIComponent(fileName.replace(/\.[^.]*$/, ""));

module.exports = {
    handler
}