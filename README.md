# HealthcareRecords Smart Contract

## Overview

`HealthcareRecords` is a Solidity smart contract for managing patient medical records on Ethereum. It ensures secure, decentralized, and transparent handling of patient data, doctor authorizations, and institutional access. Developed by **Abdennour Alouach** and **Idris Elgarrab** as part of a coursework.

## Features

- **Patient Management**: Store patient profiles (name, birth year, blood type, allergies, emergency contact).
- **Medical Records**: Add and retrieve records (diagnostics, prescriptions) with timestamps and types.
- **Doctor & Institution Registration**: Register verified doctors and institutions.
- **Authorization**: Grant/revoke access to doctors and institutions.
- **Emergency Access**: Verified doctors can access critical patient data in emergencies.
- **Admin Controls**: Manage accounts and transfer admin privileges.
- **Event Logging**: Track actions for transparency.

## Prerequisites

- Solidity ^0.8.20
- Ethereum environment (Hardhat, Truffle, or Remix)
- Node.js & npm
- MetaMask
- Ethereum client (testnet like Sepolia or local like Ganache)

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/your-username/healthcare-records.git
   cd healthcare-records
   ```
2. Install dependencies (for Hardhat):

   ```bash
   npm install
   ```
3. Compile the contract:

   ```bash
   npx hardhat compile
   ```
4. Deploy:
   - Update `scripts/deploy.js` with network config.
   - Run: `npx hardhat run scripts/deploy.js --network <network-name>`

## Usage

- **Deploy**: Deployer becomes admin.
- **Register**:
  - Patients: `registerPatient(address, name, birthYear, emergencyContact, bloodType)`
  - Doctors: `registerDoctor(address, name, specialization, licenseNumber)`
  - Institutions: `registerInstitution(address, name, institutionType, admin)`
- **Records**: Add with `addMedicalRecord(address, record, recordType)`; retrieve with `getMedicalHistory` or `getRecordsByType`.
- **Authorization**: Grant via `authorizeDoctor`/`authorizeInstitution`; revoke via `revokeDoctor`/`revokeInstitution`.
- **Emergency**: Use `emergencyAccess` for critical data.
- **Admin**: Manage accounts with `deactivatePatient`, `reactivatePatient`, `transferAdmin`.

## Testing

1. Set up Hardhat/Truffle.
2. Write tests in `test/` (JavaScript/Mocha).
3. Run: `npx hardhat test`
   - Test cases: Register patient, add record, authorize doctor, verify emergency access.

## Security

- **Access Control**: Uses modifiers (`onlyAdmin`, `onlyAuthorized`).
- **Privacy**: Consider encryption for sensitive data in production.
- **Gas**: Optimized with efficient array operations.
- **Auditability**: Events ensure traceability.

## License

MIT License. See LICENSE.

## Authors

- Abdennour Alouach
- Idris Elgarrab

## Contributing

Submit pull requests or open issues on GitHub for improvements or bugs.
