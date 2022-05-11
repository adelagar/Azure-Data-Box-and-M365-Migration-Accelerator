# Azure-Data-Box-and-M365-Migration-Accelerator
A solution accelerator to expedite the migration of data from across an organization into Microsoft 365 (M365) OneDrive by leveraging capabilities from Azure to efficiently the data into the cloud from on-premises. Potential use cases can be expanded to import or export PST files from M365. The solution can be leveraged across multiple industry verticals such as DoD, Federal Civilian Government, State and Local Government, Financial Services and Commercial customers.  This Solution is provided "as is" for general use.

**Problem Statement and Impact**

With Microsoft M365 being one of the primary Software as a Service (SaaS) solution for businesses to leverage for office productivity and collaboration. The migration process from on-premises to the cloud relies on the M365 Migration Manager, a software utility installed on a Windows Server, for OneDrive and SharePoint Online functionality. The tooling used for the migration requires access to the source data and copied from a customer’s internal network and over the public internet where their Microsoft M365 Tennant resides. The issue that may occur for clients, which might become a short-term inhibitor for success, is the total volume of data to be copied over a slow speed or high latency network topology. The concept of a rapid migration processes needed to align with a customer’s expectations of an efficient transition from on-premises to a SaaS cloud-based solution.

**Solution Accelerator Program**

The FastTrack for Azure (FTA) Team and FastTrack M365 (FT M365) Team have co-authored a Solution Accelerator Framework to leverage Azure as a Migration Factory for M365 migrations at scale. The goal of the proposed program is to leverage the capabilities from each team to accelerate data migration to OneDrive and SharePoint Online migrations, removing any migration obstacles created by less-than-ideal network or infrastructure resources.  By using this solution customers are able to shorten time to adoption, and overcome network constraints, by using the power of the cloud to perform efficient data migrations from on premises thought Azure and to M365. The Solution Accelerator Framework could also be extended to Microsoft Partners and Managed Service Providers.

**Solution and Framework Description**

The solution framework consists of identifying a potential migration project that might be impacted by the volume of data to be migrated over a low bandwidth network, or security regulations that do not allow a clear path to the internet from a customer’s internal network. Customers and partners can use this solution accelerator to establish a Migration Factory in Azure with a preconfigured Azure Resource Manager Template. The solution is designed to assist in connecting either to on-premises, attaching the environment to an existing Azure subscription, or leave it as a disconnected platform from on-premises providing flexibility for various migration scenarios. The solution includes steps that assist in ordering an Azure Data Box and copying the data for export into the Azure Migration Factory storage accounts. Once the data was seeded in the Azure storage accounts, Migration Manager can be used to complete the transfer from Azure to OneDrive for business.

* The graphic below illustrates when to use this solution accelerator over conventional methods
 <img src="/Images/WhenToUseDataBox.png" alt="When to Use DataBox" title="When to Use DataBox">
 
* Below is a high-level overview of the Migration Factory solution
 <img src="/Images/High-level_Arch.png" alt="High-Level Architecture" title="High-Level Architecture">
 

**Benefit from the Solution Accelerator**

The following are the benefits that could be gained from the proposed program

* Provides an end-to-end solution for efficiently migrating data from distributed locations or where there are concerns for network impacts into OneDrive for Business.
* The solution framework shortens the time it would otherwise take to get data from on-prem into M365.
* The graphic below illustrates when to use this solution accelerator over conventional methods

**Deploy the M365 OneDrive Migration Factory Solution Accelerator into Azure**

Below please find the solution accelerator deployment buttons for either Azure Commercial or Azure Us Government. Please note that the inputs within the JSON template can be changed based on you particular scenario. We are also adding a dash and an ordinal number to the virtual machine hostname. Example if you were to deploy two virtual machines they would appear in your Azure subscription as M365-MIGVM-1 and M365-MIGVM-2. The hostnames can be whatever you want to comply with your naming standards. Please be aware that you are limited to 15 characters for the virtual machine hostname. You have the option to deploy multiple virtual machines per your requirements.  

**High Level Azure Migration Deployment Solution Overview**

Below please find a graphic depicting what the output of the depolyment into Azure would look like. In this scenario we just deployed three virtual machines, a storage account, a virtual network, a network security group, and a route table.
<img src="/Images/AzureMigrationFactory.png" alt="High-Level Azure Migration Architecture" title="High-Level Azure Migration Architecture">

#### Microsoft Azure Commercial Click Here: ####
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fadelagar%2FAzure-Data-Box-and-M365-Migration-Accelerator%2Fmain%2Fazuredeploy.json)

#### Microsoft Azure Government Click Here: ####
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fadelagar%2FAzure-Data-Box-and-M365-Migration-Accelerator%2Fmain%2Fazuredeploy.json) 



