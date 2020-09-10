const AWS = require('aws-sdk');

AWS.config.apiVersions = {
    ssm: '2014-11-06',
    dynamodb: '2012-08-10',
    sns: '2010-03-31',
    sesv2: '2019-09-27'
}

const getTableName = async () => await getSsmParameter(process.env.DB_NAME);

async function getSsmParameter(name, withDecryption = false) {
    try {
        const ssmClient = new AWS.SSM();
        const result = await ssmClient.getParameter({
            Name: name,
            WithDecryption: withDecryption
        }).promise();
        return result.Parameter.Value;
    } catch(e) {
        console.error(e)
        throw new Error(`error on retrieving ssm parameter ${name} ${e.message}`)
    }
}

async function getCustomersCount() {
    const dynamoClient = new AWS.DynamoDB();
    const TableName = await getTableName();
    const scanResult = await dynamoClient.scan({
        TableName,
        Select: 'COUNT'
    }).promise();
    return scanResult.Count || 0;
}

async function getCustomerByEmail(email) {
    console.info(`getting customer by email: ${email}`);
    const dynamoClient = new AWS.DynamoDB();
    const TableName = await getTableName();
    const scanResult = await dynamoClient.scan({
        TableName,
        FilterExpression: 'email = :e',
        ExpressionAttributeValues: {
            ':e': { S: email }
        }
    }).promise();
    return scanResult.Count ? scanResult.Items[0] : undefined;
}

module.exports = {
    getCustomersCount,
    getSsmParameter,
    getCustomerByEmail,
    getTableName,
    AWS
    // configureAws
}