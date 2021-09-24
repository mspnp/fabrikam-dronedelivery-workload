// ------------------------------------------------------------
//  Copyright (c) Microsoft Corporation.  All rights reserved.
//  Licensed under the MIT License (MIT). See License.txt in the repo root for license information.
// ------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using Microsoft.VisualStudio.TestTools.WebTesting;

namespace Fabrikam.Shipping.LoadTests
{
    public class InvoiceRequestWebTest : WebTest
    {
        private const string ContextParamIngestUrl = "INGEST_URL";

        public InvoiceRequestWebTest()
        {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            ServicePointManager.ServerCertificateValidationCallback = RemoteCertificateValidationCallBack;
        }

        public static bool RemoteCertificateValidationCallBack(
            object sender,
            X509Certificate certificate,
            X509Chain chain,
            SslPolicyErrors sslPolicyErrors) => true;

        public override IEnumerator<WebTestRequest> GetRequestEnumerator()
        {
            var (ownerId, year, month) = CreateRandomHttpQueryArgs();

            Uri invoiceRequestUri = this.CreateInvoiceRequestUri(
                ownerId,
                year,
                month);

            var invoiceRequest = new WebTestRequest(invoiceRequestUri)
            {
                Method = "GET"
            };

            yield return invoiceRequest;
        }

        private Uri CreateInvoiceRequestUri(
            string ownerId,
            int year,
            int month)
        {
            if (!(this.Context[ContextParamIngestUrl].ToString() is var ingestUrl
                && !string.IsNullOrEmpty(ingestUrl)))
            {
                throw new ArgumentNullException($"{ContextParamIngestUrl} load test context param value can not be null");
            }

            if (!Uri.TryCreate(
                ingestUrl,
                UriKind.Absolute,
                out Uri ingestUri))
            {
                throw new ArgumentException($"{ingestUrl} is not a valid absolute URI");
            }

            if (!Uri.TryCreate(
                    ingestUri,
                    $"/api/invoices?ownerId={ownerId}&year={year}&month={month}",
                    out Uri invoiceRequestUri))
            {
                throw new ArgumentException($"{ingestUrl}/api/deliveryrequests is not a valid URI");
            }

            return invoiceRequestUri;
        }

        private static Tuple<string, int, int> CreateRandomHttpQueryArgs()
        {

            const int MinOwnerId = 0;
            const int MaxOwnerId = 127271;
            const int MinMonth = 1;
            const int MaxMonth = 12;
            int MinYear = DateTime.UtcNow.Year;
            int MaxYear = MinYear + 4;

            var random = new Random();

            int ownerId = random.Next(MinOwnerId, MaxOwnerId);
            int year = random.Next(MinYear, MaxYear);
            int month = random.Next(MinMonth, MaxMonth);

            return Tuple.Create($"o000{ownerId}", year, month);
        }
    }
}
