@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Default partner cím'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{
    serviceQuality: #X,
    sizeCategory: #S,
    dataClass: #MIXED
}
@VDM.viewType: #COMPOSITE
define view entity ZPRT_I_DEFAULT_BP_ADDRESS as select from I_BusinessPartnerDefaultAddr as BpAddrr
association [1..1] to I_Address as _ADRC
      on  BpAddrr.BusinessPartnerAddressID = _ADRC.AddressID
{
  key BusinessPartner                as BP,
  BpAddrr.BusinessPartnerAddressID   as ADDR_ID,
  BpAddrr._BusinessPartner.BusinessPartnerCategory as Type,  
  BpAddrr._BusinessPartner.LastNamePrefix,
  BpAddrr._BusinessPartner._AcademicTitleText.AcademicTitleName, 
  BpAddrr._BusinessPartner.LastName,
  BpAddrr._BusinessPartner.MiddleName,  
  BpAddrr._BusinessPartner.FirstName,
  BpAddrr._BusinessPartner.OrganizationBPName1, 
  BpAddrr._BusinessPartner.OrganizationBPName2,
  BpAddrr._BusinessPartner.OrganizationBPName3, 
  BpAddrr._BusinessPartner.OrganizationBPName4,
  BpAddrr._BusinessPartner.GroupBusinessPartnerName1, 
  BpAddrr._BusinessPartner.GroupBusinessPartnerName2, 
  BpAddrr._Address.Country           as Country,
  BpAddrr._Address.CityName          as City,
  BpAddrr._Address.PostalCode        as PostalCode,
  BpAddrr._Address.HouseNumber       as HouseNumber,
  BpAddrr._Address.Building,
  BpAddrr._Address.StreetName,
  BpAddrr._Address.StreetPrefixName,
  BpAddrr._Address.StreetSuffixName,
  BpAddrr._Address.Floor,
  BpAddrr._Address.RoomNumber,
  BpAddrr._Address.AdditionalStreetPrefixName,
  BpAddrr._Address.HouseNumberSupplementText,
  BpAddrr._Address.POBox,
  _ADRC.ZStreetTypeCode as streetabbr,
  _ADRC.POBoxPostalCode as PostalCode2
}

